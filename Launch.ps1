param([switch]$Editor, [switch]$Training, [switch]$Slayer, [switch]$Marshal, [switch]$Doctor, [switch]$Windowed, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Windowed -and $Fullscreen) { throw 'Choose either -Windowed or -Fullscreen.' }
$taskGameArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskGameArgs += '--editor' }
else {
    if ($Windowed) { $taskGameArgs += '--windowed' }
    elseif ($Fullscreen) { $taskGameArgs += '--fullscreen' }
    if ($Training) { $taskGameArgs += 'res://scenes/training/combat_sandbox.tscn' }
    if ((@($Slayer, $Marshal, $Doctor) | Where-Object { $_ }).Count -gt 1) { throw 'Choose one hero switch.' }
    if ($Slayer) { $taskGameArgs += @('--', '--hero=slayer') }
    elseif ($Marshal) { $taskGameArgs += @('--', '--hero=marshal') }
    elseif ($Doctor) { $taskGameArgs += @('--', '--hero=doctor') }
}
& $taskEngine @taskGameArgs
