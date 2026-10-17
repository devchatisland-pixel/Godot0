# One PNG per building model of docs\building_models.tsv -> docs\building_model_images\
# Run: & .\tools\render_zone_models.ps1   (opens a small Godot window while it renders)
$repo = Split-Path $PSScriptRoot
. "$repo\tools\setup-local-godot.ps1"
$names = "$env:TEMP\zone_model_names.txt"
Import-Csv "$repo\docs\building_models.tsv" -Delimiter "`t" |
    Where-Object { $_.model -notlike '(no model*' } |
    Select-Object -ExpandProperty model -Unique | Set-Content $names -Encoding utf8
& $GodotExe --rendering-driver opengl3 --resolution 320x320 --path $repo --script res://tools/render_zone_models.gd -- $names "$repo\docs\building_model_images"
