# Model audits, every step: counts per zone, pictures, memory of every model, then
# docs\audit orphelin models.docx and docs\audit resources models.docx.
# Run: & .\tools\audit_orphans.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
. "$repo\tools\setup-local-godot.ps1"
Set-Location $repo
Write-Host '=== Buildings per zone and model ===' -ForegroundColor Cyan
& "$repo\tools\dump_building_models.ps1"
Write-Host '=== Pictures of the building models ===' -ForegroundColor Cyan
& "$repo\tools\render_zone_models.ps1"
Write-Host '=== Fog island, vehicles and props (with pictures) ===' -ForegroundColor Cyan
& "$repo\tools\dump_fog_and_vehicles.ps1"
Write-Host '=== Memory of every model (all of them loaded) ===' -ForegroundColor Cyan
& $GodotExe --headless --path $repo --script res://tests/dump_used_models.gd -- "$repo\docs\used_models.tsv"
Write-Host '=== Audit documents ===' -ForegroundColor Cyan
python "$repo\tools\build_orphan_audit.py"
python "$repo\tools\build_resource_audit.py"
Write-Host 'AUDIT DONE' -ForegroundColor Green
