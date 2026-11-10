# Prints the 16 ANSI colors of the active Windows Terminal scheme as swatches.
# Usage: & .\terminal\palette-demo.ps1
$e = [char]27
$names = 'black','red','green','yellow','blue','purple','cyan','white'
$row1 = ''; $row2 = ''
for ($i = 0; $i -lt 8; $i++) {
    $row1 += "$e[4$($i)m      $e[0m "
    $row2 += "$e[10$($i)m      $e[0m "
}
Write-Host ''
Write-Host "  $row1"
Write-Host "  $row2"
Write-Host ''
Write-Host ("  " + (($names | ForEach-Object { $_.PadRight(7) }) -join ''))
Write-Host ''
