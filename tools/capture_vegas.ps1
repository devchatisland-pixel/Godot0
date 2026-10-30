# Screenshots of Las Vegas in the game (its casinos and clubs, tools/make_vegas_buildings.py), by
# day and at night: imports the assets, then runs the game with the capture runner
# (tests/capture_runner.gd, --spots).   & .\tools\capture_vegas.ps1 -Out <dir>
param([Parameter(Mandatory)] [string] $Out)
$repo = Split-Path $PSScriptRoot -Parent
. "F:\Godot0-city\tools\setup-local-godot.ps1"
Set-Location $repo
New-Item -ItemType Directory -Force $Out | Out-Null
Write-Host '=== importing assets ===' -ForegroundColor Cyan
& $GodotExe --headless --path $repo --import 2>&1 | Select-Object -Last 3
# x, z, zoom, night: the whole zone by day and at night, then four closer looks at night.
$spots = '134,190,34,0;134,190,34,1;124,180,14,1;140,182,14,1;126,202,14,1;142,198,14,1'
Write-Host "=== capturing $spots ===" -ForegroundColor Cyan
& $GodotExe --path $repo --resolution 1600x900 -- --capture $Out --spots $spots 2>&1 |
    Where-Object { $_ -match '\[Capture\]|ERROR|SCRIPT' }
Write-Host 'CAPTURE DONE' -ForegroundColor Green
