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
    & $taskEngine --headless --path $taskRoot --script res://tests/integration_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Training integration tests failed.' }
    if ($Capture) {
        & $taskEngine --path $taskRoot --script res://tests/capture.gd --resolution 1440x900 --audio-driver Dummy
        if ($LASTEXITCODE -ne 0) { throw 'Rendered capture failed.' }
    }
} finally { Pop-Location }
