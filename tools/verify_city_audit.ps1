param(
    [Parameter(Mandatory)][ValidatePattern('^city_[a-z_]+$')][string]$Test,
    [switch]$Realtime
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = & (Join-Path $PSScriptRoot 'find_godot.ps1')
$env:APPDATA = Join-Path $taskRoot '.tools/runtime'
$taskLogFolder = Join-Path $taskRoot 'artifacts/city-audits'
New-Item -ItemType Directory -Path $taskLogFolder -Force | Out-Null
$taskLog = Join-Path $taskLogFolder "$Test.log"
$taskArguments = @('--headless', '--path', $taskRoot, '--script', "res://tests/$Test.gd")
if (-not $Realtime) { $taskArguments += @('--fixed-fps', '60') }
# Godot returns zero for shutdown leaks, and its own --log-file closes before
# those diagnostics. Capture both process streams through the actual exit.
# Windows PowerShell wraps native stderr in ErrorRecords; stringify them here.
$ErrorActionPreference = 'Continue'
& $taskEngine @taskArguments 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $taskLog
$taskExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($taskExit -ne 0) { throw "City audit failed ($taskExit): $Test" }
if (Select-String -LiteralPath $taskLog -CaseSensitive -Pattern 'ERROR:|WARNING:.*(leaked|still in use)') {
    throw "City audit reported engine errors or shutdown leaks: $Test (see $taskLog)"
}
