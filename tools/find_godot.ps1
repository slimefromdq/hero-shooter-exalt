$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$candidates = @()
if ($env:GODOT_BIN) { $candidates += $env:GODOT_BIN }
$candidates += Join-Path $env:USERPROFILE 'Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$onPath = Get-Command godot, godot_console -ErrorAction SilentlyContinue
foreach ($entry in $onPath) { $candidates += $entry.Source }
foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $version = & $candidate --version
        if ($version -like '4.7.2.stable*') { return $candidate }
    }
}
throw 'Godot 4.7.2 stable was not found. Set GODOT_BIN to its console executable, or import project.godot in Godot 4.7.2.'
