param([switch]$Editor, [switch]$Training, [switch]$Windowed, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Windowed -and $Fullscreen) { throw 'Choose either -Windowed or -Fullscreen.' }
$taskGameArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskGameArgs += '--editor' }
else {
    if ($Windowed) { $taskGameArgs += '--windowed' }
    elseif ($Fullscreen) { $taskGameArgs += '--fullscreen' }
    if ($Training) { $taskGameArgs += 'res://scenes/training/combat_sandbox.tscn' }
}
& $taskEngine @taskGameArgs
