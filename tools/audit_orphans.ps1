# Orphan models audit, every step: counts per zone, pictures, then docs\audit orphelin models.docx.
# Run: & .\tools\audit_orphans.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
Set-Location $repo
Write-Host '=== Buildings per zone and model ===' -ForegroundColor Cyan
& "$repo\tools\dump_building_models.ps1"
Write-Host '=== Pictures of the building models ===' -ForegroundColor Cyan
& "$repo\tools\render_zone_models.ps1"
Write-Host '=== Fog island, vehicles and props (with pictures) ===' -ForegroundColor Cyan
& "$repo\tools\dump_fog_and_vehicles.ps1"
Write-Host '=== Audit document ===' -ForegroundColor Cyan
python "$repo\tools\build_orphan_audit.py"
Write-Host 'AUDIT DONE' -ForegroundColor Green
