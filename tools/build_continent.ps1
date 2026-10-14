# Builds the Continent building pack from procedural_city_7.glb and renders its previews
# (docs/model_previews_continent/*.png and docs/continent_buildings.png).
$ErrorActionPreference = "Stop"
if (-not $env:PREVIEW_ROOT) { $env:PREVIEW_ROOT = "F:/Godot0-city/tools/_preview_root" }
python "$PSScriptRoot\build_continent_pack.py"
if ($LASTEXITCODE -ne 0) { throw "build failed" }
python "$PSScriptRoot\render_continent_previews.py"
if ($LASTEXITCODE -ne 0) { throw "render failed" }
Write-Host "CONTINENT OK"
