param(
    [string]$InstallDir = 'C:\Winpharm',
    [string]$Token      = $env:GH_TOKEN
)

$libRepo    = 'edsonvalher/poc-winpharm-lib'
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ocxDir     = Join-Path $InstallDir 'ocx'
$markerFile = Join-Path $InstallDir '.winpharm_installed'

function Get-LibRelease {
    $apiHeaders = @{ Accept = 'application/vnd.github.v3+json' }
    if ($Token) { $apiHeaders['Authorization'] = "token $Token" }
    return Invoke-RestMethod "https://api.github.com/repos/$libRepo/releases/latest" -Headers $apiHeaders
}

function Download-LibAsset {
    param($Asset, $Dest)
    $dlHeaders = @{ Accept = 'application/octet-stream' }
    if ($Token) { $dlHeaders['Authorization'] = "token $Token" }
    Invoke-WebRequest $Asset.url -OutFile $Dest -Headers $dlHeaders -UseBasicParsing -ErrorAction Stop
}

function Install-LibComponents {
    Write-Host "Downloading library components from winpharm-lib..."
    try {
        $release = Get-LibRelease
        New-Item -ItemType Directory -Force -Path $ocxDir | Out-Null

        foreach ($asset in $release.assets) {
            if ($asset.name -match '\.ocx$') {
                $dest = Join-Path $ocxDir $asset.name
                Download-LibAsset -Asset $asset -Dest $dest
                Write-Host "  $($asset.name)"
            } elseif ($asset.name -match '\.dll$') {
                $dest = Join-Path $InstallDir $asset.name
                Download-LibAsset -Asset $asset -Dest $dest
                Write-Host "  $($asset.name)"
            }
        }
    } catch {
        Write-Host "ERROR: Could not download library components. $_"
        exit 1
    }
}

function Test-OcxRegistered {
    $keys = @(
        'HKLM:\SOFTWARE\Classes\CLSID\{05240211-f067-44db-b11d-c4f1e65ff9f7}',
        'HKLM:\SOFTWARE\Classes\CLSID\{2a0267e0-74d0-44b1-b2dd-7c0672d512f4}',
        'HKLM:\SOFTWARE\Classes\CLSID\{e01eb3b2-f615-11d5-9ec5-0003b3008f24}'
    )
    foreach ($key in $keys) {
        if (-not (Test-Path $key)) { return $false }
    }
    return $true
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

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if ((Test-OcxRegistered) -and (Test-Path $markerFile)) {
    Write-Host "Winpharm already installed. Running update..."
    & "$scriptDir\update.ps1" -InstallDir $InstallDir -Token $Token
} else {
    Write-Host "New installation detected."
    Install-LibComponents
    Write-Host ""
    Register-Ocx
    Write-Host ""
    Write-Host "Downloading all components..."
    & "$scriptDir\update.ps1" -InstallDir $InstallDir -Token $Token
    Set-Content $markerFile (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Write-Host ""
    Write-Host "Installation complete."
}
