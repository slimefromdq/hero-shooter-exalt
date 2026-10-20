param([ValidateSet("Dawn","Afternoon","Night")][string]$Lighting, [switch]$Editor, [switch]$Museum, [switch]$Defend, [switch]$Explore, [switch]$Training, [switch]$Slayer, [switch]$Marshal, [switch]$Doctor, [switch]$Huddle, [switch]$Relay, [switch]$Seeker, [switch]$Dynamo, [switch]$Wisp, [switch]$Rogue, [switch]$Samson, [switch]$Stitch, [switch]$Windowed, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Windowed -and $Fullscreen) { throw 'Choose either -Windowed or -Fullscreen.' }
if ($Museum -and $Training) { throw 'Choose either -Museum or -Training.' }
if (($Defend -or $Explore) -and -not $Museum) { throw '-Defend and -Explore require -Museum.' }
if ($Lighting -and -not $Museum) { throw '-Lighting requires -Museum.' }
if ($Defend -and $Explore) { throw 'Choose either -Defend or -Explore.' }
$taskGameArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskGameArgs += '--editor' }
else {
    if ($Windowed) { $taskGameArgs += '--windowed' }
    elseif ($Fullscreen) { $taskGameArgs += '--fullscreen' }
    if ($Training) { $taskGameArgs += 'res://scenes/training/combat_sandbox.tscn' }
    if ($Museum) { $taskGameArgs += 'res://scenes/museum/meridian_museum.tscn' }
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
if ($Museum) {
    if ('--' -notin $taskGameArgs) { $taskGameArgs += '--' }
    $taskGameArgs += '--museum'
    if ($Lighting) { $taskGameArgs += "--museum-lighting=$($Lighting.ToLowerInvariant())" }
    if ($Defend) { $taskGameArgs += '--defend' }
    if ($Explore) { $taskGameArgs += '--explore' }
}
& $taskEngine @taskGameArgs
