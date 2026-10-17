param([switch]$Editor, [switch]$Training)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Editor) { & $taskEngine --path $PSScriptRoot --editor }
elseif ($Training) { & $taskEngine --path $PSScriptRoot res://scenes/training/combat_sandbox.tscn }
else { & $taskEngine --path $PSScriptRoot }
