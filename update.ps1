param(
    [string]$InstallDir = 'C:\Winpharm'
)

$netRepo   = 'edsonvalher/poc-winpharm-net'
$cobolRepo = 'edsonvalher/poc-winpharm-cobol'
$tempDir   = Join-Path $env:TEMP 'winpharm_update'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

function Download-File {
    param($Url, $OutFile)
    try {
        Invoke-WebRequest $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-AssetUrl {
    param($Repo, $Version, $AssetName)
    return "https://github.com/$Repo/releases/download/v$Version/$AssetName"
}

function Get-ManifestUrl {
    param($Repo)
    return "https://github.com/$Repo/releases/latest/download/manifest.json"
}

Write-Host "Checking for updates..."

$netManifestOk   = Download-File -Url (Get-ManifestUrl $netRepo)   -OutFile "$tempDir\net.manifest.json"
$cobolManifestOk = Download-File -Url (Get-ManifestUrl $cobolRepo) -OutFile "$tempDir\cobol.manifest.json"

if (-not $netManifestOk -or -not $cobolManifestOk) {
    Write-Host "ERROR: Could not reach GitHub releases. Check your internet connection."
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
            $url  = Get-AssetUrl -Repo $netRepo -Version $newVer -AssetName "$name.$ext"
            $dest = Join-Path $InstallDir "$name.$ext"
            if (Download-File -Url $url -OutFile $dest) {
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
            $url  = Get-AssetUrl -Repo $cobolRepo -Version $newVer -AssetName "$name.$ext"
            $dest = Join-Path $InstallDir "$name.$ext"
            if (Download-File -Url $url -OutFile $dest) {
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
