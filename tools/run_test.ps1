# Runs one headless test script with the local Godot: & .\tools\run_test.ps1 res://tests/test_shops.gd
param([Parameter(Mandatory)] [string] $Script)
$repo = Split-Path $PSScriptRoot -Parent
. "F:\Godot0-city\tools\setup-local-godot.ps1"
Set-Location $repo
if (-not (Test-Path "$repo\.godot\imported")) {
    Write-Host '=== importing assets ===' -ForegroundColor Cyan
    & $GodotExe --headless --path $repo --import 2>&1 | Select-Object -Last 3
}
Write-Host "=== $Script ===" -ForegroundColor Cyan
& $GodotExe --headless --path $repo --script $Script 2>&1 | Select-Object -Last 60
Write-Host 'TEST DONE' -ForegroundColor Green
