# ==============================================================================
# Requiem - apply the desktop setup (idempotent, safe to run repeatedly)
#
#   -X / -Y          Clock position. Pixels ("200") or percent of the screen
#                    ("7.3%"). Default: 7.3% / 17.4% (works on any resolution).
#   -KeepOtherSkins  Leave your other active Rainmeter skins loaded.
#   -NoAutostart     Do not create the Rainmeter shortcut in the Startup folder.
#   -SkipExplorer    Do not hide the desktop icons.
#   -WhatIf          Show what would change without changing anything.
#   -Confirm         Ask before each change.
#
# Before changing Rainmeter.ini a timestamped backup is written next to it:
#   %APPDATA%\Rainmeter\Rainmeter.ini.requiem-<yyyyMMdd_HHmmss>.bak
# ==============================================================================
[CmdletBinding(SupportsShouldProcess)]
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
    $procs | Stop-Process -Force -Confirm:$false
    foreach ($p in $procs) { $p.WaitForExit(5000) | Out-Null }
}

# --- 1. First run: let Rainmeter create its settings file ---------------------
Write-Host '[1/5] Checking Rainmeter settings...' -ForegroundColor DarkRed
if (-not (Test-Path $RmIni)) {
    if (-not $PSCmdlet.ShouldProcess($RmExe, 'Start Rainmeter once to create Rainmeter.ini')) {
        Write-Host "  -> $RmIni does not exist yet; the remaining steps need it." -ForegroundColor DarkGray
        return
    }
    Start-Process $RmExe
    $t = 0
    while (-not (Test-Path $RmIni) -and $t -lt 30) { Start-Sleep -Seconds 1; $t++ }
    if (-not (Test-Path $RmIni)) { throw "Rainmeter did not create $RmIni within 30 s." }
    Start-Sleep -Seconds 2
}
# Rainmeter rewrites Rainmeter.ini on exit, so it must not run while we edit it
if ($PSCmdlet.ShouldProcess('Rainmeter', 'Stop process')) { Stop-Rainmeter }

$lines = Get-Content $RmIni -Encoding Unicode

# SkinPath comes from Rainmeter.ini (handles redirected/OneDrive Documents folders)
$skinPathLine = $lines | Where-Object { $_ -match '^SkinPath=(.+)$' } | Select-Object -First 1
if ($skinPathLine) { $SkinRoot = ($skinPathLine -replace '^SkinPath=', '').TrimEnd('\') }
else { $SkinRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins' }

# --- 2. Deploy skin (UTF-16 LE, required by Rainmeter for non-ASCII) -----------
Write-Host "[2/5] Deploying skin to $SkinRoot\$Config ..." -ForegroundColor DarkRed
$skinDir = Join-Path $SkinRoot $Config
$skinFile = Join-Path $skinDir 'Requiem.ini'
if ($PSCmdlet.ShouldProcess($skinFile, 'Write skin (UTF-16 LE)')) {
    New-Item -ItemType Directory -Force $skinDir -Confirm:$false | Out-Null
    $content = Get-Content -Raw -Encoding UTF8 $SkinSrc
    [System.IO.File]::WriteAllText($skinFile, $content, [System.Text.Encoding]::Unicode)
}

# --- 3. Write layout into Rainmeter.ini (with backup) -------------------------
Write-Host '[3/5] Writing Rainmeter layout...' -ForegroundColor DarkRed
$backup = "$RmIni.requiem-$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"

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
if ($PSCmdlet.ShouldProcess($RmIni, "Write layout [$Config] (backup: $backup)")) {
    Copy-Item $RmIni $backup -Confirm:$false
    Write-Host "  -> backup: $backup" -ForegroundColor DarkGray
    [System.IO.File]::WriteAllLines($RmIni, $out, [System.Text.Encoding]::Unicode)
}

# --- 4. Start Rainmeter + autostart -------------------------------------------
Write-Host '[4/5] Starting Rainmeter...' -ForegroundColor DarkRed
if ($PSCmdlet.ShouldProcess($RmExe, 'Start Rainmeter')) {
    Start-Process $RmExe
    $t = 0
    while (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue) -and $t -lt 10) { Start-Sleep -Seconds 1; $t++ }
    if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { throw 'Rainmeter is not running after start.' }
}

if (-not $NoAutostart) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Rainmeter.lnk'
    if (Test-Path $lnk) {
        Write-Host '  -> autostart already present' -ForegroundColor DarkGray
    } elseif ($PSCmdlet.ShouldProcess($lnk, 'Create autostart shortcut')) {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath = $RmExe
        $sc.WorkingDirectory = Split-Path $RmExe
        $sc.Save()
        Write-Host "  -> autostart created: $lnk" -ForegroundColor DarkGray
    }
}

# --- 5. Hide desktop icons ----------------------------------------------------
if ($SkipExplorer) {
    Write-Host '[5/5] skipped (-SkipExplorer)' -ForegroundColor DarkGray
} elseif ($PSCmdlet.ShouldProcess('Desktop icons', 'Hide')) {
    Write-Host '[5/5] Hiding desktop icons...' -ForegroundColor DarkRed
    & (Join-Path $Root 'toggle-desktop-icons.ps1')
}

if ($WhatIfPreference) { Write-Host 'WhatIf: nothing was changed.' -ForegroundColor Green }
else { Write-Host 'Requiem applied.' -ForegroundColor Green }
