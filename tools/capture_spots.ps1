# Screenshots of chosen places of the generated map with the game's capture runner
# (tests/capture_runner.gd, --spots "x,z,zoom,night;..."):  & .\tools\capture_spots.ps1 -Out <dir> -Spots '130,255,40,0'
param([Parameter(Mandatory)] [string] $Out, [Parameter(Mandatory)] [string] $Spots)
$repo = Split-Path $PSScriptRoot -Parent
. "F:\Godot0-city\tools\setup-local-godot.ps1"
Set-Location $repo
New-Item -ItemType Directory -Force $Out | Out-Null
Write-Host "=== capturing $Spots ===" -ForegroundColor Cyan
& $GodotExe --path $repo --resolution 1600x900 -- --capture $Out --spots $Spots 2>&1 |
    Where-Object { $_ -match '\[Capture\]|ERROR|SCRIPT' }
Write-Host 'CAPTURE DONE' -ForegroundColor Green
