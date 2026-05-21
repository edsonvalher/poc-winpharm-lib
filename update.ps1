param(
    [string]$InstallDir = 'C:\Winpharm',
    [string]$Token      = $env:GH_TOKEN
)

$netRepo   = 'edsonvalher/poc-winpharm-net'
$cobolRepo = 'edsonvalher/poc-winpharm-cobol'
$tempDir   = Join-Path $env:TEMP 'winpharm_update'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

function Get-ReleaseAsset {
    param($Repo, $AssetName, $OutFile, $Version)
    $apiHeaders = @{ Accept = 'application/vnd.github.v3+json' }
    if ($Token) { $apiHeaders['Authorization'] = "token $Token" }

    $releaseUrl = if ($Version) {
        "https://api.github.com/repos/$Repo/releases/tags/v$Version"
    } else {
        "https://api.github.com/repos/$Repo/releases/latest"
    }

    $release = Invoke-RestMethod $releaseUrl -Headers $apiHeaders
    $asset   = $release.assets | Where-Object { $_.name -eq $AssetName }
    if (-not $asset) { throw "Asset '$AssetName' not found in release $($release.tag_name)" }

    $dlHeaders = @{ Accept = 'application/octet-stream' }
    if ($Token) { $dlHeaders['Authorization'] = "token $Token" }
    Invoke-WebRequest $asset.url -OutFile $OutFile -Headers $dlHeaders -UseBasicParsing -ErrorAction Stop
}

function Download-Asset {
    param($Repo, $AssetName, $OutFile, $Version)
    try {
        Get-ReleaseAsset -Repo $Repo -AssetName $AssetName -OutFile $OutFile -Version $Version
        return $true
    } catch {
        return $false
    }
}

Write-Host "Checking for updates..."

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

$updated = 0

Write-Host ""
Write-Host "net v$($newNet.net.version)"
foreach ($prop in $newNet.net.files.PSObject.Properties) {
    $name     = $prop.Name
    $newVer   = $prop.Value
    $localVer = if ($localNet) { $localNet.net.files.$name } else { $null }

    if ($newVer -ne $localVer) {
        $fromStr = if ($localVer) { $localVer } else { 'not installed' }
        Write-Host "  $name  $fromStr -> $newVer  [downloading]"
        $downloaded = $false
        foreach ($ext in @('dll', 'exe')) {
            $dest = Join-Path $InstallDir "$name.$ext"
            if (Download-Asset -Repo $netRepo -AssetName "$name.$ext" -OutFile $dest -Version $newVer) {
                $downloaded = $true
                $updated++
                break
            }
        }
        if (-not $downloaded) { Write-Warning "  Could not download $name" }
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
        Write-Host "  $name  $fromStr -> $newVer  [downloading]"
        $downloaded = $false
        foreach ($ext in @('dll', 'exe')) {
            $dest = Join-Path $InstallDir "$name.$ext"
            if (Download-Asset -Repo $cobolRepo -AssetName "$name.$ext" -OutFile $dest -Version $newVer) {
                $downloaded = $true
                $updated++
                break
            }
        }
        if (-not $downloaded) { Write-Warning "  Could not download $name" }
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

Write-Host ""
Write-Host "----------------------------------------"
Write-Host " Installed versions"
Write-Host "   net   v$($newNet.net.version)"
Write-Host "   cobol v$($newCobol.cobol.version)"
Write-Host "----------------------------------------"
