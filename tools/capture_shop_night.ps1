# Screenshots of the shops of the development island in the game, by day and at night (each shop
# with its night copy in front of it): imports the assets, then runs the game with the capture
# runner (tests/capture_runner.gd, --spots).   & .\tools\capture_shop_night.ps1 -Out <dir>
param([Parameter(Mandatory)] [string] $Out)
$repo = Split-Path $PSScriptRoot -Parent
. "F:\Godot0-city\tools\setup-local-godot.ps1"
Set-Location $repo
New-Item -ItemType Directory -Force $Out | Out-Null
Write-Host '=== importing assets ===' -ForegroundColor Cyan
& $GodotExe --headless --path $repo --import 2>&1 | Select-Object -Last 3
# x, z, zoom, night: the row in five parts at night, then the whole row by day and at night.
$spots = '38,323,9,1;49,323,9,1;60,323,9,1;71,323,9,1;81,323,9,1;58,323,28,0;58,323,28,1'
Write-Host "=== capturing $spots ===" -ForegroundColor Cyan
& $GodotExe --path $repo --resolution 1600x900 -- --capture $Out --spots $spots 2>&1 |
    Where-Object { $_ -match '\[Capture\]|\[Shops\]|ERROR|SCRIPT' }
Write-Host 'CAPTURE DONE' -ForegroundColor Green
