param(
    [string]$InstallDir = 'C:\Winpharm'
)

$netRepo    = 'edsonvalher/poc-winpharm-net'
$cobolRepo  = 'edsonvalher/poc-winpharm-cobol'
$installDir = $InstallDir
$tempDir    = Join-Path $env:TEMP 'winpharm_update'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$baseNet   = "https://github.com/$netRepo/releases/latest/download"
$baseCobol = "https://github.com/$cobolRepo/releases/latest/download"

Write-Host "Checking for updates..."

try {
    Invoke-WebRequest "$baseNet/manifest.json"   -OutFile "$tempDir\net.manifest.json"   -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest "$baseCobol/manifest.json" -OutFile "$tempDir\cobol.manifest.json" -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "ERROR: Could not reach GitHub releases. Check your connection."
    exit 1
}

$newNet   = Get-Content "$tempDir\net.manifest.json"   | ConvertFrom-Json
$newCobol = Get-Content "$tempDir\cobol.manifest.json" | ConvertFrom-Json

$localNetPath   = Join-Path $installDir 'net.manifest.json'
$localCobolPath = Join-Path $installDir 'cobol.manifest.json'
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
            try {
                $dest = Join-Path $installDir "$name.$ext"
                Invoke-WebRequest "$baseNet/$name.$ext" -OutFile $dest -UseBasicParsing -ErrorAction Stop
                $downloaded = $true
                $updated++
                break
            } catch {}
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
        try {
            $dest = Join-Path $installDir "$name.dll"
            Invoke-WebRequest "$baseCobol/$name.dll" -OutFile $dest -UseBasicParsing -ErrorAction Stop
            $updated++
        } catch { Write-Warning "  Could not download $name.dll" }
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
