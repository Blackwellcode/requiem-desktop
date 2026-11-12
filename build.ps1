# ==============================================================================
# Builds dist\Requiem_<version>.rmskin (Rainmeter skin package).
#
# Format: a zip archive followed by a 16-byte footer
#   bytes 0-7  : length of the zip data, unsigned 64-bit little-endian
#   bytes 8-15 : 00 'R' 'M' 'S' 'K' 'I' 'N' 00
# Contents: RMSKIN.ini, Skins\Requiem\Requiem.ini, Layouts\Requiem\Rainmeter.ini
# Text files are stored as UTF-16 LE, the encoding Rainmeter expects.
# ==============================================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$Root    = $PSScriptRoot
$SkinSrc = Join-Path $Root 'rainmeter\Requiem\Requiem.ini'
$Layout  = Join-Path $Root 'rainmeter\Layouts\Requiem\Rainmeter.ini'
$Dist    = Join-Path $Root 'dist'

$skinText = Get-Content -Raw -Encoding UTF8 $SkinSrc
$verLine = ($skinText -split "`r?`n") | Where-Object { $_ -match '^Version=(.+)$' } | Select-Object -First 1
if (-not $verLine) { throw 'Version= missing in [Metadata] of Requiem.ini' }
$Version = ($verLine -replace '^Version=', '').Trim()

$rmskinIni = @"
[rmskin]
Name=Requiem
Author=Blackwell Code
Version=$Version
LoadType=Layout
Load=Requiem
MinimumRainmeter=4.5
MinimumWindows=10.0
"@

$entries = [ordered]@{
    'RMSKIN.ini'                  = $rmskinIni
    'Skins\Requiem\Requiem.ini'   = $skinText
    'Layouts\Requiem\Rainmeter.ini' = (Get-Content -Raw -Encoding UTF8 $Layout)
}

New-Item -ItemType Directory -Force $Dist | Out-Null
$out = Join-Path $Dist "Requiem_$Version.rmskin"

$ms = New-Object System.IO.MemoryStream
$zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Create, $true)
try {
    foreach ($name in $entries.Keys) {
        $entry = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try {
            $bytes = [System.Text.Encoding]::Unicode.GetPreamble() + [System.Text.Encoding]::Unicode.GetBytes($entries[$name])
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
    }
} finally { $zip.Dispose() }

$zipBytes = $ms.ToArray(); $ms.Dispose()
$footer = New-Object byte[] 16
[BitConverter]::GetBytes([uint64]$zipBytes.Length).CopyTo($footer, 0)   # little-endian on x86/x64
[byte[]](0x00, 0x52, 0x4D, 0x53, 0x4B, 0x49, 0x4E, 0x00) | ForEach-Object -Begin { $i = 8 } -Process { $footer[$i] = $_; $i++ }

$fs = [System.IO.File]::Create($out)
try {
    $fs.Write($zipBytes, 0, $zipBytes.Length)
    $fs.Write($footer, 0, 16)
} finally { $fs.Dispose() }

Write-Host ("Built {0} (zip {1} bytes + 16 byte footer)" -f $out, $zipBytes.Length)

# Checksum file to publish next to the package (verify: Get-FileHash -Algorithm SHA256 <file>)
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $out).Hash.ToLowerInvariant()
$sums = Join-Path $Dist 'SHA256SUMS'
Set-Content -LiteralPath $sums -Value ('{0}  {1}' -f $hash, (Split-Path $out -Leaf)) -Encoding ASCII
Write-Host "SHA256 $hash -> $sums"
