param(
    [string]$InstallDir = 'C:\Winpharm',
    [string]$Token      = $env:GH_TOKEN
)

$libRepo   = 'edsonvalher/poc-winpharm-lib'
$netRepo   = 'edsonvalher/poc-winpharm-net'
$cobolRepo = 'edsonvalher/poc-winpharm-cobol'
$ocxDir    = Join-Path $InstallDir 'ocx'
$tempDir   = Join-Path $env:TEMP 'winpharm_update'
$markerFile = Join-Path $InstallDir '.winpharm_installed'

$apiHeaders = @{ Accept = 'application/vnd.github.v3+json' }
if ($Token) { $apiHeaders['Authorization'] = "token $Token" }

# --- Helpers ---

function Get-ReleaseAsset {
    param($Repo, $AssetName, $OutFile, $Version)
    $url = if ($Version) {
        "https://api.github.com/repos/$Repo/releases/tags/v$Version"
    } else {
        "https://api.github.com/repos/$Repo/releases/latest"
    }
    $release = Invoke-RestMethod $url -Headers $apiHeaders
    $asset   = $release.assets | Where-Object { $_.name -eq $AssetName }
    if (-not $asset) { throw "Asset '$AssetName' not found in release $($release.tag_name)" }
    $dlHeaders = @{ Accept = 'application/octet-stream' }
    if ($Token) { $dlHeaders['Authorization'] = "token $Token" }
    Invoke-WebRequest $asset.url -OutFile $OutFile -Headers $dlHeaders -UseBasicParsing -ErrorAction Stop
}

function Download-Asset {
    param($Repo, $AssetName, $OutFile, $Version)
    try { Get-ReleaseAsset -Repo $Repo -AssetName $AssetName -OutFile $OutFile -Version $Version; return $true }
    catch { return $false }
}

function Test-OcxRegistered {
    $keys = @(
        'HKLM:\SOFTWARE\Classes\CLSID\{05240211-f067-44db-b11d-c4f1e65ff9f7}',
        'HKLM:\SOFTWARE\Classes\CLSID\{2a0267e0-74d0-44b1-b2dd-7c0672d512f4}',
        'HKLM:\SOFTWARE\Classes\CLSID\{e01eb3b2-f615-11d5-9ec5-0003b3008f24}'
    )
    foreach ($key in $keys) { if (-not (Test-Path $key)) { return $false } }
    return $true
}

# --- Install mode: lib components ---

function Install-LibComponents {
    Write-Host "Downloading library components..."
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$libRepo/releases/latest" -Headers $apiHeaders
        New-Item -ItemType Directory -Force -Path $ocxDir | Out-Null
        foreach ($asset in $release.assets) {
            if ($asset.name -match '\.ocx$') {
                $dest = Join-Path $ocxDir $asset.name
                $dlHeaders = @{ Accept = 'application/octet-stream' }
                if ($Token) { $dlHeaders['Authorization'] = "token $Token" }
                Invoke-WebRequest $asset.url -OutFile $dest -Headers $dlHeaders -UseBasicParsing -ErrorAction Stop
                Write-Host "  $($asset.name)"
            } elseif ($asset.name -match '\.dll$') {
                $dest = Join-Path $InstallDir $asset.name
                $dlHeaders = @{ Accept = 'application/octet-stream' }
                if ($Token) { $dlHeaders['Authorization'] = "token $Token" }
                Invoke-WebRequest $asset.url -OutFile $dest -Headers $dlHeaders -UseBasicParsing -ErrorAction Stop
                Write-Host "  $($asset.name)"
            }
        }
    } catch {
        Write-Host "ERROR: Could not download library components. $_"
        exit 1
    }
}

function Register-Ocx {
    Write-Host "Registering Datacap OCX components..."
    foreach ($file in Get-ChildItem $ocxDir -Filter '*.ocx') {
        $result = Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/s `"$($file.FullName)`"" -Wait -PassThru
        if ($result.ExitCode -eq 0) {
            Write-Host "  $($file.Name) registered."
        } else {
            Write-Warning "  Failed to register $($file.Name) (exit code $($result.ExitCode))."
        }
    }
}

# --- Update mode: net + cobol components ---

function Update-Components {
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    try {
        Get-ReleaseAsset -Repo $netRepo   -AssetName 'manifest.json' -OutFile "$tempDir\net.manifest.json"
        Get-ReleaseAsset -Repo $cobolRepo -AssetName 'manifest.json' -OutFile "$tempDir\cobol.manifest.json"
    } catch {
        Write-Host "ERROR: Could not reach GitHub releases. $_"
        exit 1
    }

    $newNet   = Get-Content "$tempDir\net.manifest.json"   | ConvertFrom-Json
    $newCobol = Get-Content "$tempDir\cobol.manifest.json" | ConvertFrom-Json

    $localNetPath   = Join-Path $InstallDir 'net.manifest.json'
    $localCobolPath = Join-Path $InstallDir 'cobol.manifest.json'
    $localNet   = if (Test-Path $localNetPath)   { Get-Content $localNetPath   | ConvertFrom-Json } else { $null }
    $localCobol = if (Test-Path $localCobolPath) { Get-Content $localCobolPath | ConvertFrom-Json } else { $null }

    $updated  = 0
    $changes  = [System.Collections.Generic.List[string]]::new()
    $prevNet   = if ($localNet)   { $localNet.net.version }     else { $null }
    $prevCobol = if ($localCobol) { $localCobol.cobol.version } else { $null }

    Write-Host ""
    Write-Host "net v$($newNet.net.version)"
    foreach ($prop in $newNet.net.files.PSObject.Properties) {
        $name     = $prop.Name
        $newVer   = $prop.Value
        $localVer = if ($localNet) { $localNet.net.files.$name } else { $null }
        if ($newVer -ne $localVer) {
            $fromStr = if ($localVer) { $localVer } else { 'not installed' }
            $downloaded = $false
            foreach ($ext in @('dll', 'exe')) {
                $dest = Join-Path $InstallDir "$name.$ext"
                if (Download-Asset -Repo $netRepo -AssetName "$name.$ext" -OutFile $dest -Version $newVer) {
                    $downloaded = $true; $updated++; break
                }
            }
            if ($downloaded) {
                Write-Host "  $name  $fromStr -> $newVer  [downloading]... " -NoNewline
                Write-Host "installed" -ForegroundColor Green
                $changes.Add("   $name  $fromStr  ->  $newVer")
            }
        } else {
            Write-Host "  $name  $newVer  [ok]"
        }
    }

    Write-Host ""
    Write-Host "cobol v$($newCobol.cobol.version)"
    foreach ($prop in $newCobol.cobol.files.PSObject.Properties) {
        $name     = $prop.Name
        $newVer   = $prop.Value
        $localVer = if ($localCobol) { $localCobol.cobol.files.$name } else { $null }
        if ($newVer -ne $localVer) {
            $fromStr = if ($localVer) { $localVer } else { 'not installed' }
            $downloaded = $false
            foreach ($ext in @('dll', 'exe')) {
                $dest = Join-Path $InstallDir "$name.$ext"
                if (Download-Asset -Repo $cobolRepo -AssetName "$name.$ext" -OutFile $dest -Version $newVer) {
                    $downloaded = $true; $updated++; break
                }
            }
            if ($downloaded) {
                Write-Host "  $name  $fromStr -> $newVer  [downloading]... " -NoNewline
                Write-Host "installed" -ForegroundColor Green
                $changes.Add("   $name  $fromStr  ->  $newVer")
            }
        } else {
            Write-Host "  $name  $newVer  [ok]"
        }
    }

    Write-Host ""
    if ($updated -gt 0) {
        Copy-Item "$tempDir\net.manifest.json"   $localNetPath   -Force
        Copy-Item "$tempDir\cobol.manifest.json" $localCobolPath -Force
        Write-Host "$updated file(s) updated."
    } else {
        Write-Host "All files are up to date."
    }

    Remove-Item $tempDir -Recurse -Force

    $netVerLine   = if ($prevNet)   { "v$prevNet  ->  v$($newNet.net.version)" }   else { "v$($newNet.net.version)" }
    $cobolVerLine = if ($prevCobol) { "v$prevCobol  ->  v$($newCobol.cobol.version)" } else { "v$($newCobol.cobol.version)" }

    Write-Host ""
    Write-Host "----------------------------------------"
    if ($changes.Count -gt 0) {
        Write-Host " Updated components"
        foreach ($line in $changes) { Write-Host $line }
        Write-Host ""
    }
    Write-Host " Versions"
    Write-Host "   net    $netVerLine"
    Write-Host "   cobol  $cobolVerLine"
    Write-Host "----------------------------------------"
}

# --- Main ---

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (Test-Path $markerFile) {
    Write-Host "Winpharm installation detected. Checking for updates..."
    Update-Components
} else {
    Write-Host "New installation detected."
    Write-Host ""
    Install-LibComponents
    Write-Host ""
    Register-Ocx
    Write-Host ""
    Write-Host "Downloading all components..."
    Update-Components
    Set-Content $markerFile (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Write-Host ""
    Write-Host "Installation complete."
}
