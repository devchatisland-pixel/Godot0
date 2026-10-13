# Local deploy of the web build on http://localhost:8080 (port 8080 only).
# Run from anywhere: & F:\Godot0-city\tools\deploy.ps1
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

Step 'Stopping old container on 8080'
$running = docker ps -q --filter 'name=^godot0-city-web-1$'
if ($running) { docker stop godot0-city-web-1 } else { Write-Host 'already stopped' }

Step 'Building and starting web (live output)'
docker compose up --build -d web
if ($LASTEXITCODE -ne 0) { Fail 'docker compose build/up failed, old images kept' }

Step 'Removing leftover untagged images from previous builds'
docker image prune -f

Step 'Status'
docker ps --filter 'name=^godot0-city-web-1$' --format '{{.Names}}  {{.Status}}  {{.Ports}}'
Write-Host "`nDEPLOY OK -> http://localhost:8080 (hard-refresh with Ctrl+F5)" -ForegroundColor Green
