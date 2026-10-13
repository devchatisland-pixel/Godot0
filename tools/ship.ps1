# Ships the current branch to main (commit, push, PR, merge) with live output,
# then runs tools/deploy.ps1 (rebuild on http://localhost:8080).
# Run from the session's checkout (a worktree branch, never main):
#   & .\tools\ship.ps1 -Title "What changed" -Paths file1,file2
# -Paths: files to stage and commit first (omit when everything is already committed).
# -NoDeploy: stop after the merge.
param(
    [Parameter(Mandatory)] [string] $Title,
    [string[]] $Paths = @(),
    [switch] $NoDeploy
)
$ErrorActionPreference = 'Stop'

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "SHIP FAILED: $msg" -ForegroundColor Red; exit 1 }

$branch = git rev-parse --abbrev-ref HEAD
if ($branch -eq 'main') { Fail 'run this from a work branch, not main' }
Write-Host "branch: $branch"

if ($Paths.Count -gt 0) {
    Step 'Committing'
    git add -- $Paths
    if ($LASTEXITCODE -ne 0) { Fail 'git add failed' }
    git commit -m $Title -m 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
    if ($LASTEXITCODE -ne 0) { Fail 'git commit failed' }
}

Step 'Pushing'
git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { Fail 'git push failed' }
git fetch -q origin main
$ahead = git rev-list --count origin/main..HEAD
if ([int]$ahead -eq 0) { Write-Host 'nothing new for main' }
else {
    git log --oneline origin/main..HEAD

    Step 'Pull request into main'
    $robot = [char]::ConvertFromUtf32(0x1F916)
    $body = "$Title`n`n$robot Generated with [Claude Code](https://claude.com/claude-code)"
    $existing = gh pr list --head $branch --base main --state open --json number --jq '.[0].number'
    if ($existing) { $pr = $existing; Write-Host "using open PR #$pr" }
    else {
        gh pr create --base main --head $branch --title $Title --body $body
        if ($LASTEXITCODE -ne 0) { Fail 'gh pr create failed' }
        $pr = gh pr list --head $branch --base main --state open --json number --jq '.[0].number'
    }

    Step "Merging PR #$pr"
    $ErrorActionPreference = 'Continue'
    $checks = gh pr checks $pr 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0 -or "$checks" -notmatch 'no checks') { gh pr checks $pr --watch }
    gh pr merge $pr --merge
    if ($LASTEXITCODE -ne 0) { Fail "gh pr merge #$pr failed" }
    gh pr view $pr --json state,url --jq '.state + "  " + .url'
}

if ($NoDeploy) {
    Step 'Updating main checkout F:\Godot0-city'
    git -C F:\Godot0-city pull --ff-only
    if ($LASTEXITCODE -ne 0) { Fail 'merged, but pulling the main checkout failed (local changes or not on main)' }
    Write-Host "`nSHIP OK (on main, deploy skipped)" -ForegroundColor Green
    exit 0
}
& F:\Godot0-city\tools\deploy.ps1
