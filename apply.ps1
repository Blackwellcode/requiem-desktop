# ==============================================================================
# Requiem - Desktop-Setup anwenden (Seele Blackwell Gothic)
# Idempotent: kann beliebig oft ausgefuehrt werden.
#   -SkipExplorer  : Desktop-Icons/Explorer-Neustart ueberspringen
#   -NoAutostart   : keine Rainmeter-Verknuepfung im Autostart-Ordner anlegen
# ==============================================================================
param(
    [switch]$SkipExplorer,
    [switch]$NoAutostart,
    [int]$X = 200,
    [int]$Y = 200
)
$ErrorActionPreference = 'Stop'

$Root      = $PSScriptRoot
$RmExe     = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$SkinSrc   = Join-Path $Root 'rainmeter\Requiem\Requiem.ini'
$SkinDir   = Join-Path $env:USERPROFILE 'Documents\Rainmeter\Skins\Requiem'
$Config    = 'Requiem'

if (-not (Test-Path $RmExe)) { throw "Rainmeter nicht gefunden: $RmExe" }
if (-not (Test-Path $SkinSrc)) { throw "Skin-Quelle fehlt: $SkinSrc" }

# 1. Skin deployen (Rainmeter braucht UTF-16 LE fuer Nicht-ASCII-Zeichen)
Write-Host '[1/4] Skin deployen...' -ForegroundColor DarkRed
New-Item -ItemType Directory -Force $SkinDir | Out-Null
$content = Get-Content -Raw -Encoding UTF8 $SkinSrc
[System.IO.File]::WriteAllText((Join-Path $SkinDir 'Requiem.ini'), $content, [System.Text.Encoding]::Unicode)

# 2. Rainmeter beenden, damit Rainmeter.ini nicht beim Beenden ueberschrieben wird
Write-Host '[2/4] Rainmeter-Layout schreiben...' -ForegroundColor DarkRed
Get-Process Rainmeter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
$rmIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (-not (Test-Path $rmIni)) { throw "Rainmeter.ini fehlt (Rainmeter einmal starten): $rmIni" }
$lines = Get-Content $rmIni -Encoding Unicode

# Bestehende Requiem-Sektion entfernen, alle anderen Configs deaktivieren
$out = New-Object System.Collections.Generic.List[string]
$section = ''
foreach ($l in $lines) {
    if ($l -match '^\[(.+)\]$') { $section = $Matches[1] }
    if ($section -eq $Config) { continue }
    if ($section -ne 'Rainmeter' -and $l -match '^Active=') { $out.Add('Active=0'); continue }
    $out.Add($l)
}
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
[System.IO.File]::WriteAllLines($rmIni, $out, [System.Text.Encoding]::Unicode)

# 3. Rainmeter starten
Write-Host '[3/4] Rainmeter starten...' -ForegroundColor DarkRed
Start-Process $RmExe
Start-Sleep -Seconds 3
if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { throw 'Rainmeter laeuft nach dem Start nicht.' }

# Autostart: die winget-Installation von Rainmeter legt keinen an
if (-not $NoAutostart) {
    $startup = [Environment]::GetFolderPath('Startup')
    $lnk = Join-Path $startup 'Rainmeter.lnk'
    if (-not (Test-Path $lnk)) {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath = $RmExe
        $sc.WorkingDirectory = Split-Path $RmExe
        $sc.Save()
        Write-Host "  -> Autostart angelegt: $lnk" -ForegroundColor DarkGray
    } else {
        Write-Host '  -> Autostart bereits vorhanden' -ForegroundColor DarkGray
    }
}

# 4. Desktop-Icons ausblenden (rueckgaengig: Rechtsklick > Ansicht > Desktopsymbole anzeigen)
if (-not $SkipExplorer) {
    Write-Host '[4/4] Desktop-Icons ausblenden...' -ForegroundColor DarkRed
    # HideIcons in der Registry allein greift ohne Explorer-Neustart nicht; deshalb direkt umschalten.
    & (Join-Path $Root 'toggle-desktop-icons.ps1')
} else {
    Write-Host '[4/4] uebersprungen (-SkipExplorer)' -ForegroundColor DarkGray
}

Write-Host 'Requiem angewendet.' -ForegroundColor Green
