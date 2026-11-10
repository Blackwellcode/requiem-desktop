# Erzeugt das Requiem-Icon (Heiligenschein + Glutkreuz) als PNG.
# Aufruf: & F:\aktiv\desktop-requiem\icons\make-icon.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$S   = 256
$Out = Join-Path $PSScriptRoot 'requiem.png'

function New-Pt([double]$x, [double]$y) { New-Object System.Drawing.PointF -ArgumentList ([single]$x), ([single]$y) }

# Lateinisches Kreuz mit spitzen Enden. w = Balkenbreite, tip = Laenge der Spitze.
function Get-CrossPoints([double]$w, [double]$tip) {
    $cx = 128.0; $cy = 100.0          # Kreuzungspunkt (oberes Drittel)
    $top = 30.0; $bottom = 230.0; $left = 58.0; $right = 198.0
    $h = $w / 2.0
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    $pts.Add((New-Pt $cx $top))
    $pts.Add((New-Pt ($cx + $h) ($top + $tip)))
    $pts.Add((New-Pt ($cx + $h) ($cy - $h)))
    $pts.Add((New-Pt ($right - $tip) ($cy - $h)))
    $pts.Add((New-Pt $right $cy))
    $pts.Add((New-Pt ($right - $tip) ($cy + $h)))
    $pts.Add((New-Pt ($cx + $h) ($cy + $h)))
    $pts.Add((New-Pt ($cx + $h) ($bottom - $tip)))
    $pts.Add((New-Pt $cx $bottom))
    $pts.Add((New-Pt ($cx - $h) ($bottom - $tip)))
    $pts.Add((New-Pt ($cx - $h) ($cy + $h)))
    $pts.Add((New-Pt ($left + $tip) ($cy + $h)))
    $pts.Add((New-Pt $left $cy))
    $pts.Add((New-Pt ($left + $tip) ($cy - $h)))
    $pts.Add((New-Pt ($cx - $h) ($cy - $h)))
    $pts.Add((New-Pt ($cx - $h) ($top + $tip)))
    return ,$pts.ToArray()
}

function New-Brush([int]$a, [int]$r, [int]$g, [int]$b) { New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, $r, $g, $b)) }

$bmp = New-Object System.Drawing.Bitmap $S, $S
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
try {
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gfx.Clear([System.Drawing.Color]::Transparent)

    # Dunkle Scheibe (#100000) und silberner Heiligenschein (#A0A09E)
    $gfx.FillEllipse((New-Brush 240 16 0 0), 12, 12, 232, 232)
    $ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 160, 160, 158)), 8
    $gfx.DrawEllipse($ring, 18, 18, 220, 220)

    # Glut-Schein: breitere, transparente Kreuze (#C03E45)
    foreach ($i in 5..1) {
        [System.Drawing.PointF[]]$glow = Get-CrossPoints (28 + $i * 10) 20
        $gfx.FillPolygon((New-Brush 26 192 62 69), $glow)
    }
    # Kern-Kreuz
    [System.Drawing.PointF[]]$core = Get-CrossPoints 28 20
    $gfx.FillPolygon((New-Brush 255 192 62 69), $core)
}
finally {
    $gfx.Dispose()
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$small = New-Object System.Drawing.Bitmap $bmp, 32, 32
$small.Save((Join-Path $PSScriptRoot 'requiem_32_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Host "Icon geschrieben: $Out"
