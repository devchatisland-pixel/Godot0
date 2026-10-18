# Local deploy of the web build on http://localhost:8080 (port 8080 only).
# Run from anywhere: & F:\Godot0-city\tools\deploy.ps1
# The web export runs with the local Godot (import cache kept in F:\Godot0-city\.godot,
# so only new or changed assets are imported); the container only serves build/web.
# Touches only the godot0-city-web-1 container and dangling (untagged) images.
$ErrorActionPreference = 'Stop'
$repo = 'F:\Godot0-city'
Set-Location $repo

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "DEPLOY FAILED: $msg" -ForegroundColor Red; exit 1 }

Step 'Updating main checkout'
$branch = git rev-parse --abbrev-ref HEAD
if ($branch -ne 'main') { Fail "main checkout is on '$branch', not main" }
git pull --ff-only
if ($LASTEXITCODE -ne 0) { Fail 'git pull --ff-only failed (local changes or diverged main)' }
git log --oneline -1

Step 'Local Godot'
. "$repo\tools\setup-local-godot.ps1"

Step 'Importing assets (only new or changed ones)'
& $GodotExe --headless --path $repo --import
if ($LASTEXITCODE -ne 0) { Fail 'godot --import failed' }

Step 'Exporting web build'
$next = "$repo\build\web-next"
New-Item -ItemType Directory -Force $next | Out-Null
New-Item -ItemType File -Force "$repo\build\.gdignore" | Out-Null
Remove-Item -Recurse -Force "$next\*"
& $GodotExe --headless --path $repo --export-release 'Web' $next\index.html
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$next\index.pck")) { Fail 'web export failed, the site keeps the previous build' }

$changed = @(git status --short --untracked-files=no)
if ($changed.Count -gt 0) {
    Write-Host "WARNING: the import rewrote $($changed.Count) tracked file(s) (e.g. .import upgrades); commit them on a branch so the checkout stays clean:" -ForegroundColor Yellow
    $changed | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
}

Step 'Swapping in the new build and restarting 8080'
$running = docker ps -q --filter 'name=^godot0-city-web-1$'
if ($running) { docker stop godot0-city-web-1 }
if (Test-Path "$repo\build\web") { Remove-Item -Recurse -Force "$repo\build\web" }
Move-Item $next "$repo\build\web"
docker compose up -d web
if ($LASTEXITCODE -ne 0) { Fail 'docker compose up failed' }

Step 'Removing leftover untagged images'
docker image prune -f

Step 'Status'
docker ps --filter 'name=^godot0-city-web-1$' --format '{{.Names}}  {{.Status}}  {{.Ports}}'
Write-Host "`nDEPLOY OK -> http://localhost:8080 (hard-refresh with Ctrl+F5)" -ForegroundColor Green
