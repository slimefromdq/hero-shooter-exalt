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
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/roster_expansion_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Relay, Dynamo or Wisp combat and integration failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/crouch_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Crouch, low cover, slide priority or stronger boot failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/health_bars_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Overhead or roster health bars failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/menu_flow_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Startup, settings or queued hero selection failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/qol_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'QoL movement, reload, hero, menus or training checks failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/camera_framing_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Wide camera framing failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/rules_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Combat/movement rule tests failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/match_feedback_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Spawn healing, elimination attribution or match feedback failed.' }

    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/huddle_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Huddle colony combat, mobility or lifecycle failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/care_heroes_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Marshal or Doctor combat/integration failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer combat, status or collision rules failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_integration_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer hero selection, AI or scene integration failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_abilities_overhaul_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer steering, ballistic knives or axe orientation failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_presentation_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer presentation parity, budgets or cleanup failed.' }
    & $taskEngine --headless --path $taskRoot --script res://tests/slayer_model_asset_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer model import, facial morphs or material preservation failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_character_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Live Slayer rig, attachments, skin weights or lifecycle failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/slayer_revision_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Slayer input buffering, trap toss, feedback or throw checks failed.' }
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
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_railing_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'City sloped railing or landing clearance failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_stair_openings_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Street paving overhangs an underground stair opening.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_route_audit.gd
    if ($LASTEXITCODE -ne 0) { throw 'Full-city stair width, traversal or route joins failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_geometry_audit.gd
    if ($LASTEXITCODE -ne 0) { throw 'Rendered city structural surfaces do not match collision.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_arcade_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Shopping arcade, cover or repaired roof traversal failed.' }
    & $taskEngine --headless --path $taskRoot --fixed-fps 60 --script res://tests/city_navigation_regression.gd
    if ($LASTEXITCODE -ne 0) { throw 'City navigation recovery or healing route failed.' }
    if ($Capture) {
        & $taskEngine --path $taskRoot --script res://tests/slayer_character_test.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Live Slayer model rendered inspection failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_slayer_character_city.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Authored Slayer city render failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_slayer_abilities.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Slayer ability overhaul rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_slayer_presentation.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Slayer Phase 1 rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/roster_input_test.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Relay, Dynamo or Wisp native input failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_roster.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Roster rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_crouch.gd --windowed --resolution 1600x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Crouch and slide rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_health_bars.gd --windowed --resolution 1600x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Health bar rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/qol_input_test.gd --windowed --resolution 1440x900 --audio-driver Dummy
        if ($LASTEXITCODE -ne 0) { throw 'Native wheel input, map interaction or local umbrella fade failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_qol.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'QoL rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/huddle_test.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Huddle native input failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_huddle.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Huddle rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/care_heroes_test.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Marshal and Doctor native input/integration failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_care_heroes.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Marshal and Doctor rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/slayer_revision_test.gd --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Slayer native E / 4 input checks failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_slayer.gd --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Slayer rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/fullscreen_test.gd --resolution 1280x800 --audio-driver Dummy
        if ($LASTEXITCODE -ne 0) { throw 'Native fullscreen, paused shortcuts or display transitions failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture.gd --resolution 1440x900 --audio-driver Dummy
        if ($LASTEXITCODE -ne 0) { throw 'Rendered capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_city.gd --resolution 1920x1080 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Rendered city capture failed.' }
        & $taskEngine --path $taskRoot --script res://tests/capture_city_geometry.gd --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
        if ($LASTEXITCODE -ne 0) { throw 'Rendered city route and stair capture failed.' }
    }
} finally { Pop-Location }
