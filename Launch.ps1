param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$taskEngine = & (Join-Path $PSScriptRoot 'tools/find_godot.ps1')
if ($Editor) { & $taskEngine --path $PSScriptRoot --editor }
else { & $taskEngine --path $PSScriptRoot }
