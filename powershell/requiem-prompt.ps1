# Requiem-Prompt fuer Windows PowerShell 5.1 (Blackwell Gothic)
# Wird aus $PROFILE per Dot-Sourcing geladen. Datei bewusst ASCII-only:
# Sonderzeichen werden per [char] erzeugt, damit PS 5.1 die Datei ohne BOM korrekt liest.
#
# Aufbau:
#   <Kreuz> <Pfad>  <git-Branch>
#   <Pfeil>
# Kreuz glutrot = Administrator, silber = normaler Benutzer.
# Pfeil glutrot = letzter Befehl ok, hellrot = letzter Befehl fehlgeschlagen.

$script:RqEsc     = [char]27
$script:RqCross   = [char]0x271F   # Lateinisches Kreuz (outline)
$script:RqArrow   = [char]0x276F   # Heavy right-pointing angle
$script:RqIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$script:RqHasGit  = [bool](Get-Command git -ErrorAction SilentlyContinue)

function script:RqColor([int]$r, [int]$g, [int]$b) { "$script:RqEsc[38;2;$r;$g;${b}m" }

function global:prompt {
    $ok    = $?
    $e     = $script:RqEsc
    $reset = "$e[0m"
    $ember  = RqColor 192 62 69
    $silver = RqColor 160 160 158
    $dim    = RqColor 127 126 124
    $text   = RqColor 220 216 212
    $fail   = RqColor 224 90 97

    $path = $executionContext.SessionState.Path.CurrentLocation.ProviderPath
    if ($path.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }

    $branch = ''
    if ($script:RqHasGit -and $executionContext.SessionState.Path.CurrentLocation.Provider.Name -eq 'FileSystem') {
        $b = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $b) { $branch = "  $dim$b$reset" }
    }

    $crossColor = if ($script:RqIsAdmin) { $ember } else { $silver }
    $arrowColor = if ($ok) { $ember } else { $fail }

    $host.UI.RawUI.WindowTitle = "Requiem  $path"
    "`n$crossColor$script:RqCross$reset $text$path$reset$branch`n$arrowColor$script:RqArrow$reset "
}
