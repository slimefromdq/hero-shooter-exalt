param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = & (Join-Path $PSScriptRoot 'find_godot.ps1')
$taskRuntime = Join-Path $taskRoot '.tools/runtime'
New-Item -ItemType Directory -Path $taskRuntime -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $taskRuntime 'Godot') -Force | Out-Null
$taskSettings = Join-Path $taskRuntime 'Godot/editor_settings-4.7.tres'
if (-not (Test-Path -LiteralPath $taskSettings)) {
    Set-Content -LiteralPath $taskSettings -Value @('[gd_resource type="EditorSettings" format=3]', '', '[resource]', 'filesystem/on_save/safe_save_on_backup_then_rename = false')
}
# Verification keeps generated editor/user data inside this checkout.
$env:APPDATA = $taskRuntime
Push-Location -LiteralPath $taskRoot
try {
    & $taskEngine --headless --path $taskRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/rules_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Combat/movement rule tests failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/close_combat_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Melee engagement / throw choreography tests failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/guard_drill_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Guard drill or personal key bindings failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/block_feedback_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Block feedback or reload mobility failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/traversal_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Mantle, wall jump or umbrella vault checks failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/traversal_flow_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Held mantle input or wall-kick momentum checks failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/mantle_exit_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Mantle speed, momentum handoff or exit jump checks failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/integration_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Training integration tests failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/city_rules_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'City capture, health pickup or protection checks failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/city_integration_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'City navigation, respawn or reset checks failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_traversal_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'City physical stair, subway or camera traversal failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_transition_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'City/training scene transitions or cleanup failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_geometry_audit.gd
    if ($LASTEXITCODE -ne 0) { throw 'Rendered city structural surfaces do not match collision.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_arcade_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Shopping arcade, cover or repaired roof traversal failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_navigation_regression.gd
    if ($LASTEXITCODE -ne 0) { throw 'City navigation recovery or healing route failed.' }
    if ($Capture) {
        & $taskEngine --path $taskRoot --script res://tests/capture.gd --resolution 1440x900 --audio-driver Dummy
        if ($LASTEXITCODE -ne 0) { throw 'Rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_city.gd --resolution 1920x1080 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Rendered city capture failed.' }
    }
} finally { Pop-Location }
