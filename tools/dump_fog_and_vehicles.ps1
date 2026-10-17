# Fog island models + every vehicle of the map, per zone, with a picture of each model.
# Run: & .\tools\dump_fog_and_vehicles.ps1  -> docs\fog_and_vehicles.tsv + docs\fog_vehicle_images\
$repo = Split-Path $PSScriptRoot
. "$repo\tools\setup-local-godot.ps1"
$tsv = "$repo\docs\fog_and_vehicles.tsv"
& $GodotExe --headless --path $repo --script res://tests/dump_fog_and_vehicles.gd -- $tsv
$names = "$env:TEMP\fog_vehicle_names.txt"
Import-Csv $tsv -Delimiter "`t" | Select-Object -ExpandProperty key -Unique | Set-Content $names -Encoding utf8
& $GodotExe --rendering-driver opengl3 --resolution 320x320 --path $repo --script res://tools/render_zone_models.gd -- $names "$repo\docs\fog_vehicle_images"
