# The CI of docker/run-tests.sh, run with the local Godot (no Docker): each headless test in turn,
# then a summary. A test fails on a non-zero exit code or a script error in its output.
#   & .\tools\local_ci.ps1 [-Out <dir>] [-Shots]
# -Out: where the zoning map (and the screenshots) go (default: docker-out).
# -Shots: also take the screenshots of key places (runs the game, needs a GPU).
param([string] $Out = 'docker-out', [switch] $Shots)
$repo = Split-Path $PSScriptRoot -Parent
. "F:\Godot0-city\tools\setup-local-godot.ps1"
Set-Location $repo
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path

Write-Host '=== Importing assets ===' -ForegroundColor Cyan
& $GodotExe --headless --path $repo --import 2>&1 | Select-Object -Last 3

$tests = @(
    @('Generation test', 'res://tests/test_generation.gd', @()),
    @('Urban island, BT tower islet, watchtowers', 'res://tests/test_urban_island.gd', @()),
    @('Map audit (buildings, zones, fog island, road problems)', 'res://tests/test_map_audit.gd', @()),
    @('Top-down zoning map', 'res://tests/debug_map.gd', @('--', "$Out\map.png")),
    @('Chunk benchmark', 'res://tests/bench_chunks.gd', @())
)
$results = @()
foreach ($t in $tests) {
    Write-Host "`n=== $($t[0]) ===" -ForegroundColor Cyan
    $log = & $GodotExe --headless --path $repo --script $t[1] @($t[2]) 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $log | Where-Object { $_ -match '\[Test\]|\[Audit\]|\[Bench\]|FAIL|SCRIPT ERROR|Parse Error|Assertion' } |
        Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
    $errors = @($log | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Assertion failed' }).Count
    $fails = @($log | Where-Object { $_ -match '\[Test\] FAIL:' }).Count
    $ok = ($code -eq 0 -and $errors -eq 0)
    $results += [pscustomobject]@{ Test = $t[0]; Exit = $code; ScriptErrors = $errors; Fails = $fails; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }) }
}

if ($Shots) {
    Write-Host "`n=== Screenshots -> $Out ===" -ForegroundColor Cyan
    & $GodotExe --path $repo --resolution 1600x900 -- --capture $Out 2>&1 |
        Where-Object { $_ -match '\[Capture\]|SCRIPT ERROR' }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($results.Result -contains 'FAIL') { Write-Host 'LOCAL CI FAILED' -ForegroundColor Red } else { Write-Host 'LOCAL CI OK' -ForegroundColor Green }
