# ==============================================================================
# Static checks (read-only, no system changes). Exit code 0 = all passed.
#   1. Every .ps1 file parses without errors.
#   2. apply.ps1 supports -WhatIf/-Confirm and writes the Rainmeter.ini backup
#      before it overwrites Rainmeter.ini.
#   3. Every http(s) link in tracked text files points to an allowed host.
# ==============================================================================
param(
    # Alternative apply.ps1 to check (used to prove the checks fail on an old version)
    [string]$ApplyPath
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$failures = New-Object System.Collections.Generic.List[string]

# --- 1. Parser ----------------------------------------------------------------
$scripts = Get-ChildItem $Root -Recurse -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\(\.git|dist)\\' }
foreach ($f in $scripts) {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    foreach ($e in $errors) { $failures.Add("parse: $($f.Name):$($e.Extent.StartLineNumber) $($e.Message)") }
}
Write-Host "parsed $($scripts.Count) scripts"

# --- 2. apply.ps1 contract ----------------------------------------------------
$applyPath = if ($ApplyPath) { $ApplyPath } else { Join-Path $Root 'apply.ps1' }
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($applyPath, [ref]$tokens, [ref]$errors)

$binding = $ast.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }
$sp = $binding.NamedArguments | Where-Object { $_.ArgumentName -eq 'SupportsShouldProcess' }
if (-not $sp) { $failures.Add('apply.ps1: [CmdletBinding(SupportsShouldProcess)] missing') }

$calls = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -or $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)
$backupAt = ($calls | Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] -and $_.GetCommandName() -eq 'Copy-Item' -and $_.Extent.Text -match '\$RmIni\s+\$backup' } | Select-Object -First 1)
$writeAt  = ($calls | Where-Object { $_ -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $_.Member.Extent.Text -eq 'WriteAllLines' -and $_.Extent.Text -match '\$RmIni' } | Select-Object -First 1)
if (-not $backupAt) { $failures.Add('apply.ps1: backup Copy-Item $RmIni $backup not found') }
elseif (-not $writeAt) { $failures.Add('apply.ps1: WriteAllLines($RmIni, ...) not found') }
elseif ($backupAt.Extent.StartOffset -gt $writeAt.Extent.StartOffset) { $failures.Add('apply.ps1: Rainmeter.ini is written before the backup') }

# A change is guarded when it sits inside "if (...ShouldProcess...)" or follows, in an enclosing
# block, an "if (-not ...ShouldProcess...) { ... return }".
function Test-Guarded([System.Management.Automation.Language.Ast]$Node) {
    $child = $Node
    $p = $Node.Parent
    while ($p) {
        if ($p -is [System.Management.Automation.Language.IfStatementAst]) {
            foreach ($clause in $p.Clauses) { if ($clause.Item1.Extent.Text -match 'ShouldProcess') { return $true } }
        }
        if ($p -is [System.Management.Automation.Language.StatementBlockAst] -or $p -is [System.Management.Automation.Language.NamedBlockAst]) {
            foreach ($s in $p.Statements) {
                if ($s.Extent.StartOffset -ge $child.Extent.StartOffset) { break }
                if ($s -is [System.Management.Automation.Language.IfStatementAst] -and
                    $s.Clauses[0].Item1.Extent.Text -match '^-not\s+\$PSCmdlet\.ShouldProcess' -and
                    $s.Clauses[0].Item2.Extent.Text -match '\breturn\b') { return $true }
            }
        }
        $child = $p
        $p = $p.Parent
    }
    return $false
}
$changes = $calls | Where-Object {
    $_.Extent.Text -match '^\[System\.IO\.File\]::Write' -or
    $_.Extent.Text -match '\.(CreateShortcut|Save)\(' -or
    ($_ -is [System.Management.Automation.Language.CommandAst] -and $_.GetCommandName() -in 'Copy-Item', 'Start-Process', 'New-Item', 'Stop-Process', 'Remove-Item', 'Set-ItemProperty')
}
# Stop-Process lives in the helper Stop-Rainmeter; its single call site must be guarded instead.
$changes = @($changes | Where-Object { -not ($_.Extent.Text -match '^\$procs \| Stop-Process' -or $_.Extent.Text -match '^Stop-Process') })
foreach ($c in $changes) {
    if (-not (Test-Guarded $c)) { $failures.Add("apply.ps1:$($c.Extent.StartLineNumber) change outside ShouldProcess: $($c.Extent.Text)") }
}
$stopCalls = $calls | Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] -and $_.GetCommandName() -eq 'Stop-Rainmeter' }
foreach ($c in $stopCalls) {
    if (-not (Test-Guarded $c)) { $failures.Add("apply.ps1:$($c.Extent.StartLineNumber) Stop-Rainmeter outside ShouldProcess") }
}
if (@($changes).Count -eq 0) { $failures.Add('apply.ps1: no state-changing calls found - check the test') }

# --- 3. Link hosts ------------------------------------------------------------
$allowedHosts = @('github.com', 'www.rainmeter.net', 'windhawk.net')
Push-Location $Root
try { $tracked = @(git ls-files) } finally { Pop-Location }
if ($LASTEXITCODE -ne 0 -or $tracked.Count -eq 0) { $failures.Add('git ls-files failed'); $tracked = @() }
$textExt = '.md', '.ps1', '.ini', '.json', '.yaml', '.yml', '.txt', ''
foreach ($rel in $tracked) {
    if ([IO.Path]::GetExtension($rel) -notin $textExt) { continue }
    $path = Join-Path $Root $rel
    $n = 0
    foreach ($line in [System.IO.File]::ReadAllLines($path)) {
        $n++
        foreach ($m in [regex]::Matches($line, 'https?://([^/\s)>"''`]+)')) {
            $h = $m.Groups[1].Value.ToLowerInvariant()
            if ($h -notin $allowedHosts) { $failures.Add("link: ${rel}:$n host '$h' not allowed") }
        }
    }
}
Write-Host "checked links in $($tracked.Count) tracked files"

if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'all static checks passed' -ForegroundColor Green
exit 0
