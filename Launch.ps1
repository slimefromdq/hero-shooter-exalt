param([ValidateSet("Dawn","Afternoon","Night")][string]$Lighting, [switch]$Editor, [switch]$Museum, [switch]$Temple, [switch]$Defend, [switch]$Explore, [switch]$Training, [switch]$Slayer, [switch]$Marshal, [switch]$Doctor, [switch]$Huddle, [switch]$Relay, [switch]$Seeker, [switch]$Dynamo, [switch]$Wisp, [switch]$Rogue, [switch]$Samson, [switch]$Stitch, [switch]$Windowed, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Windowed -and $Fullscreen) { throw 'Choose either -Windowed or -Fullscreen.' }
if ((@($Museum, $Temple, $Training) | Where-Object { $_ }).Count -gt 1) { throw 'Choose one of -Museum, -Temple or -Training.' }
if (($Defend -or $Explore) -and -not ($Museum -or $Temple)) { throw '-Defend and -Explore require -Museum or -Temple.' }
if ($Lighting -and -not $Museum) { throw '-Lighting requires -Museum.' }
if ($Defend -and $Explore) { throw 'Choose either -Defend or -Explore.' }
$taskGameArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskGameArgs += '--editor' }
else {
    if ($Windowed) { $taskGameArgs += '--windowed' }
    elseif ($Fullscreen) { $taskGameArgs += '--fullscreen' }
    if ($Training) { $taskGameArgs += 'res://scenes/training/combat_sandbox.tscn' }
    if ($Museum) { $taskGameArgs += 'res://scenes/museum/meridian_museum.tscn' }
    if ($Temple) { $taskGameArgs += 'res://scenes/temple/sakura_veil.tscn' }
    if ((@($Slayer, $Marshal, $Doctor, $Huddle, ($Relay -or $Seeker), $Dynamo, $Wisp, $Rogue, $Samson, $Stitch) | Where-Object { $_ }).Count -gt 1) { throw 'Choose one hero switch.' }
    if ($Samson) { $taskGameArgs += @('--', '--hero=samson', '--direct') }
    elseif ($Stitch) { $taskGameArgs += @('--', '--hero=stitch', '--direct') }
    elseif ($Relay -or $Seeker) { $taskGameArgs += @('--', '--hero=relay', '--direct') }
    elseif ($Dynamo) { $taskGameArgs += @('--', '--hero=dynamo', '--direct') }
    elseif ($Wisp -or $Rogue) { $taskGameArgs += @('--', '--hero=wisp', '--direct') }
    elseif ($Huddle) { $taskGameArgs += @("--", "--hero=huddle", "--direct") }
    elseif ($Slayer) { $taskGameArgs += @('--', '--hero=slayer', '--direct') }
    elseif ($Marshal) { $taskGameArgs += @('--', '--hero=marshal', '--direct') }
    elseif ($Doctor) { $taskGameArgs += @('--', '--hero=doctor', '--direct') }
}
if ($Temple) {
    if ('--' -notin $taskGameArgs) { $taskGameArgs += '--' }
    $taskGameArgs += '--temple'
    if ($Defend) { $taskGameArgs += '--temple-team=1' }
    if ($Explore) { $taskGameArgs += '--explore' }
}
if ($Museum) {
    if ('--' -notin $taskGameArgs) { $taskGameArgs += '--' }
    $taskGameArgs += '--museum'
    if ($Lighting) { $taskGameArgs += "--museum-lighting=$($Lighting.ToLowerInvariant())" }
    if ($Defend) { $taskGameArgs += '--defend' }
    if ($Explore) { $taskGameArgs += '--explore' }
}
& $taskEngine @taskGameArgs
