param(
    [ValidateRange(1, 7200)][int]$Seconds = 1200,
    [int]$Seed = 76,
    [switch]$Rendered
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = & (Join-Path $PSScriptRoot 'find_godot.ps1')
$env:APPDATA = Join-Path $taskRoot '.tools/runtime'
$taskMode = if ($Rendered) { 'rendered' } else { 'headless' }
$taskLog = Join-Path $taskRoot "artifacts/full-roster-soak-$Seed-$taskMode.log"
$taskReportPath = Join-Path $taskRoot "artifacts/full-roster-soak-$Seed.json"
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'artifacts') -Force | Out-Null
if (Test-Path -LiteralPath $taskReportPath) { Remove-Item -LiteralPath $taskReportPath }
$taskFrameLimit = (2 * $Seconds + 2 * [Math]::Min($Seconds, 60) + 360) * 60
$taskArguments = @('--path', $taskRoot, '--fixed-fps', '60', '--quit-after', "$taskFrameLimit", '--script', 'res://tests/full_roster_soak.gd')
if ($Rendered) { $taskArguments += @('--windowed', '--resolution', '1280x800', '--audio-driver', 'Dummy') }
else { $taskArguments += '--headless' }
$taskArguments += @('--', "--seconds=$Seconds", "--seed=$Seed")
# Preserve late shutdown stderr too: an engine leak need not change its exit code.
$ErrorActionPreference = 'Continue'
& $taskEngine @taskArguments 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $taskLog
$taskExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($taskExit -ne 0) { throw "Roster soak failed ($taskExit); see $taskLog" }
if (Select-String -LiteralPath $taskLog -CaseSensitive -Pattern 'ERROR:|WARNING:.*(leaked|still in use)') {
    throw "Roster soak reported engine errors or shutdown leaks; see $taskLog"
}
$taskReport = Get-Content -LiteralPath $taskReportPath -Raw | ConvertFrom-Json
if ($taskReport.matches.Count -ne 4 -or $taskReport.transitions[-1].destination -ne 'empty_tree' -or $taskReport.failures.Count -ne 0) {
    throw "Roster soak was incomplete or failed; see $taskReportPath"
}
