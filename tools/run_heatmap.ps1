# Polygon heatmap of the whole map: Godot dumps the triangle budget, Python draws the PNG.
#   & .\tools\run_heatmap.ps1
# Godot runs on the main checkout (import cache kept there); the PNG lands in this checkout's docs\.
$ErrorActionPreference = 'Stop'
$repo = 'F:\Godot0-city'
$godot = 'C:\Tools\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$here = Split-Path $PSScriptRoot -Parent

Write-Host '=== Counting triangles (Godot, renderer on) ==='
& $godot --path $repo --rendering-driver opengl3 --script res://tools/poly_heatmap.gd
if ($LASTEXITCODE -ne 0) { Write-Host 'HEATMAP FAILED: Godot step'; return }

$json = Join-Path $env:APPDATA 'Godot\app_userdata\Isometric Island City\poly_heatmap.json'
if (-not (Test-Path $json)) { Write-Host "HEATMAP FAILED: $json not written"; return }

Write-Host '=== Drawing the PNG ==='
$out = Join-Path $here 'docs\poly_heatmap.png'
python (Join-Path $here 'tools\poly_heatmap.py') $json $out
if ($LASTEXITCODE -ne 0) { Write-Host 'HEATMAP FAILED: python step'; return }
Write-Host "HEATMAP OK -> $out"
