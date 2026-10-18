param([switch]$Editor, [switch]$Training, [switch]$Slayer, [switch]$Marshal, [switch]$Doctor, [switch]$Huddle, [switch]$Relay, [switch]$Dynamo, [switch]$Wisp, [switch]$Windowed, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Windowed -and $Fullscreen) { throw 'Choose either -Windowed or -Fullscreen.' }
$taskGameArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskGameArgs += '--editor' }
else {
    if ($Windowed) { $taskGameArgs += '--windowed' }
    elseif ($Fullscreen) { $taskGameArgs += '--fullscreen' }
    if ($Training) { $taskGameArgs += 'res://scenes/training/combat_sandbox.tscn' }
    if ((@($Slayer, $Marshal, $Doctor, $Huddle, $Relay, $Dynamo, $Wisp) | Where-Object { $_ }).Count -gt 1) { throw 'Choose one hero switch.' }
    if ($Relay) { $taskGameArgs += @('--', '--hero=relay', '--direct') }
    elseif ($Dynamo) { $taskGameArgs += @('--', '--hero=dynamo', '--direct') }
    elseif ($Wisp) { $taskGameArgs += @('--', '--hero=wisp', '--direct') }
    elseif ($Huddle) { $taskGameArgs += @("--", "--hero=huddle", "--direct") }
    elseif ($Slayer) { $taskGameArgs += @('--', '--hero=slayer', '--direct') }
    elseif ($Marshal) { $taskGameArgs += @('--', '--hero=marshal', '--direct') }
    elseif ($Doctor) { $taskGameArgs += @('--', '--hero=doctor', '--direct') }
}
& $taskEngine @taskGameArgs
