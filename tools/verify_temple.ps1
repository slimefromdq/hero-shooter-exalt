param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $taskRoot '.tools/runtime'
$taskEngine = & (Join-Path $PSScriptRoot 'find_godot.ps1')
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'artifacts/temple') -Force | Out-Null
foreach ($taskTest in @('temple_rules_test','temple_geometry_test','temple_traversal_test','temple_menu_test','temple_integration_test')) {
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script "res://tests/$taskTest.gd"
    if ($LASTEXITCODE -ne 0) { throw "Sakura Veil verification failed: $taskTest" }
}
if ($Capture) {
    & $taskEngine --path $taskRoot --fixed-fps 60 --resolution 1400x900 --script res://tests/capture_temple.gd
    if ($LASTEXITCODE -ne 0) { throw 'Sakura Veil capture failed.' }
}
