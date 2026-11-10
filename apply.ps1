# ==============================================================================
# Requiem - apply the desktop setup (idempotent, safe to run repeatedly)
#
#   -X / -Y          Clock position. Pixels ("200") or percent of the screen
#                    ("7.3%"). Default: 7.3% / 17.4% (works on any resolution).
#   -KeepOtherSkins  Leave your other active Rainmeter skins loaded.
#   -NoAutostart     Do not create the Rainmeter shortcut in the Startup folder.
#   -SkipExplorer    Do not hide the desktop icons.
#
# Before changing Rainmeter.ini a timestamped backup is written next to it:
#   %APPDATA%\Rainmeter\Rainmeter.ini.requiem-<yyyyMMdd_HHmmss>.bak
# ==============================================================================
param(
    [string]$X = '7.3%',
    [string]$Y = '17.4%',
    [switch]$KeepOtherSkins,
    [switch]$NoAutostart,
    [switch]$SkipExplorer
)
$ErrorActionPreference = 'Stop'

$Root    = $PSScriptRoot
$Config  = 'Requiem'
$SkinSrc = Join-Path $Root 'rainmeter\Requiem\Requiem.ini'
$RmIni   = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'

if ($X -notmatch '^\d+(\.\d+)?%?$' -or $Y -notmatch '^\d+(\.\d+)?%?$') {
    throw "Invalid position '$X' / '$Y'. Use pixels (200) or percent (7.3%)."
}
if (-not (Test-Path $SkinSrc)) { throw "Skin source missing: $SkinSrc" }

# --- Rainmeter install location -----------------------------------------------
function Get-RainmeterExe {
    $candidates = @()
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Rainmeter', 'HKLM:\SOFTWARE\Rainmeter') {
        $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($item -and $item.'(default)') { $candidates += (Join-Path $item.'(default)' 'Rainmeter.exe') }
    }
    $candidates += Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw 'Rainmeter not found. Install it first: winget install --id Rainmeter.Rainmeter --exact'
}
$RmExe = Get-RainmeterExe

function Stop-Rainmeter {
    $procs = @(Get-Process Rainmeter -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return }
    $procs | Stop-Process -Force
    foreach ($p in $procs) { $p.WaitForExit(5000) | Out-Null }
}

# --- 1. First run: let Rainmeter create its settings file ---------------------
Write-Host '[1/5] Checking Rainmeter settings...' -ForegroundColor DarkRed
if (-not (Test-Path $RmIni)) {
    Start-Process $RmExe
    $t = 0
    while (-not (Test-Path $RmIni) -and $t -lt 30) { Start-Sleep -Seconds 1; $t++ }
    if (-not (Test-Path $RmIni)) { throw "Rainmeter did not create $RmIni within 30 s." }
    Start-Sleep -Seconds 2
}
Stop-Rainmeter   # Rainmeter rewrites Rainmeter.ini on exit, so it must not run while we edit it

$lines = Get-Content $RmIni -Encoding Unicode

# SkinPath comes from Rainmeter.ini (handles redirected/OneDrive Documents folders)
$skinPathLine = $lines | Where-Object { $_ -match '^SkinPath=(.+)$' } | Select-Object -First 1
if ($skinPathLine) { $SkinRoot = ($skinPathLine -replace '^SkinPath=', '').TrimEnd('\') }
else { $SkinRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins' }

# --- 2. Deploy skin (UTF-16 LE, required by Rainmeter for non-ASCII) -----------
Write-Host "[2/5] Deploying skin to $SkinRoot\$Config ..." -ForegroundColor DarkRed
$skinDir = Join-Path $SkinRoot $Config
New-Item -ItemType Directory -Force $skinDir | Out-Null
$content = Get-Content -Raw -Encoding UTF8 $SkinSrc
[System.IO.File]::WriteAllText((Join-Path $skinDir 'Requiem.ini'), $content, [System.Text.Encoding]::Unicode)

# --- 3. Write layout into Rainmeter.ini (with backup) -------------------------
Write-Host '[3/5] Writing Rainmeter layout...' -ForegroundColor DarkRed
$backup = "$RmIni.requiem-$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
Copy-Item $RmIni $backup
Write-Host "  -> backup: $backup" -ForegroundColor DarkGray

$out = New-Object System.Collections.Generic.List[string]
$section = ''
foreach ($l in $lines) {
    if ($l -match '^\[(.+)\]$') { $section = $Matches[1] }
    if ($section -eq $Config) { continue }
    if (-not $KeepOtherSkins -and $section -ne 'Rainmeter' -and $l -match '^Active=') { $out.Add('Active=0'); continue }
    $out.Add($l)
}
while ($out.Count -gt 0 -and $out[$out.Count - 1] -eq '') { $out.RemoveAt($out.Count - 1) }
$out.Add('')
$out.Add("[$Config]")
$out.Add('Active=1')
$out.Add("WindowX=$X")
$out.Add("WindowY=$Y")
$out.Add('ClickThrough=1')
$out.Add('Draggable=0')
$out.Add('SnapEdges=0')
$out.Add('KeepOnScreen=1')
$out.Add('AlwaysOnTop=-2')
[System.IO.File]::WriteAllLines($RmIni, $out, [System.Text.Encoding]::Unicode)

# --- 4. Start Rainmeter + autostart -------------------------------------------
Write-Host '[4/5] Starting Rainmeter...' -ForegroundColor DarkRed
Start-Process $RmExe
$t = 0
while (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue) -and $t -lt 10) { Start-Sleep -Seconds 1; $t++ }
if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { throw 'Rainmeter is not running after start.' }

if (-not $NoAutostart) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Rainmeter.lnk'
    if (-not (Test-Path $lnk)) {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath = $RmExe
        $sc.WorkingDirectory = Split-Path $RmExe
        $sc.Save()
        Write-Host "  -> autostart created: $lnk" -ForegroundColor DarkGray
    } else {
        Write-Host '  -> autostart already present' -ForegroundColor DarkGray
    }
}

# --- 5. Hide desktop icons ----------------------------------------------------
if (-not $SkipExplorer) {
    Write-Host '[5/5] Hiding desktop icons...' -ForegroundColor DarkRed
    & (Join-Path $Root 'toggle-desktop-icons.ps1')
} else {
    Write-Host '[5/5] skipped (-SkipExplorer)' -ForegroundColor DarkGray
}

Write-Host 'Requiem applied.' -ForegroundColor Green
