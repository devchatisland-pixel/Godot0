# Counts buildings per zone and model with the local Godot (vehicles left out).
# Run: & .\tools\dump_building_models.ps1   -> writes docs\building_models.tsv
$repo = Split-Path $PSScriptRoot
. "$repo\tools\setup-local-godot.ps1"
$out = "$repo\docs\building_models.tsv"
if (-not (Test-Path "$repo\.godot\global_script_class_cache.cfg")) {
    Write-Host 'First run in this checkout: importing the project...'
    & $GodotExe --headless --path $repo --import
}
& $GodotExe --headless --path $repo --script res://tests/dump_building_models.gd -- $out
