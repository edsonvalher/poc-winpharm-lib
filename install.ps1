param(
    [string]$InstallDir = 'C:\Winpharm'
)

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ocxDir     = Join-Path $scriptDir 'ocx'
$dllDir     = Join-Path $scriptDir 'dll'
$markerFile = Join-Path $InstallDir '.winpharm_installed'

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
    $ocxFiles = @('dsiEMVX.ocx', 'dsiPDCX.ocx', 'dsiCLIENTX.ocx')
    foreach ($file in $ocxFiles) {
        $path = Join-Path $ocxDir $file
        if (Test-Path $path) {
            $result = Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/s `"$path`"" -Wait -PassThru
            if ($result.ExitCode -eq 0) {
                Write-Host "  $file registered."
            } else {
                Write-Warning "  Failed to register $file (exit code $($result.ExitCode))."
            }
        } else {
            Write-Warning "  $file not found in ocx/."
        }
    }
}

function Copy-LibDlls {
    Write-Host "Copying library files..."
    if (-not (Test-Path $dllDir)) { Write-Warning "  dll/ folder not found - skipping."; return }
    Get-ChildItem $dllDir -Filter '*.dll' | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $InstallDir $_.Name) -Force
        Write-Host "  $($_.Name)"
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if ((Test-OcxRegistered) -and (Test-Path $markerFile)) {
    Write-Host "Winpharm already installed. Running update..."
    & "$scriptDir\update.ps1" -InstallDir $InstallDir
} else {
    Write-Host "New installation detected."
    Register-Ocx
    Write-Host ""
    Copy-LibDlls
    Write-Host ""
    Write-Host "Downloading all components..."
    & "$scriptDir\update.ps1" -InstallDir $InstallDir
    Set-Content $markerFile (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Write-Host ""
    Write-Host "Installation complete."
}
