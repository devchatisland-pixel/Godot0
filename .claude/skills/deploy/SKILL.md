---
name: deploy
description: Use when the user says "deploy" on the Godot city project. Fully automated and fully visible - runs tools/ship.ps1 (commit/push/PR/merge) and tools/deploy.ps1 (pull, local Godot import + web export, restart nginx on 8080, prune leftover images) in the user's Terminal panel so they watch every step live.
---

# Deploy (local, port 8080 only, fully automated)

Site: http://localhost:8080, container `godot0-city-web-1` (service `web`), built from the main checkout `F:/Godot0-city`.

Do every step yourself. Never reply with commands for the user to copy and run.
Every step that changes something (commit, push, PR, merge, pull, docker) runs in the user's Terminal panel so they see it live.
Never do those through Bash or background tasks; Bash is only for read-only checks (`git status`, `git diff`).

## Steps
1. **Check what is pending** (read-only, Bash ok): `git status --short` and `git log origin/main..HEAD --oneline` in the session's checkout.
2. **Run everything in the user's Terminal panel** with `mcp__terminal__run_in_terminal` (load it via ToolSearch if deferred), title `deploy 8080`:
   - Pending work (session on a work branch, e.g. a worktree): cwd = the session's checkout, command
     `& .\tools\ship.ps1 -Title "<clear commit/PR title>" -Paths <file1>,<file2>`
     (`-Paths` = only the files of the change, never `FREEMODELS/_incoming/`; omit `-Paths` if already committed).
     It commits, pushes, opens the PR into `main`, waits for checks if any, merges, then runs `deploy.ps1`.
   - Nothing pending: cwd `F:\Godot0-city`, command `& F:\Godot0-city\tools\deploy.ps1`.
   `deploy.ps1` pulls `main` (ff-only), makes sure the local Godot 4.6.3 + web templates exist (`tools/setup-local-godot.ps1`, one-time download), imports only new/changed assets (cache kept in `F:\Godot0-city\.godot`), exports to `build/web-next` and only if that succeeds swaps it into `build/web`, restarts `godot0-city-web-1` (plain nginx serving `build/web`, no image build), then `docker image prune -f`.
   Never force-push, never push to main directly.
   If `run_in_terminal` reports the line was not started (it can happen with long argument lists), check `git status` (nothing half-done), then write that exact line into a one-line `ship-now.ps1` in the session's checkout (untracked, not in `-Paths`), run `& .\ship-now.ps1`, and delete it afterwards.
3. **Watch it finish** with `mcp__terminal__read_terminal` (tab_id from step 2, `wait_for_output_ms` up to ~120000, repeat). Usually about a minute; the first run downloads Godot and does one full import.
   Done when it prints `DEPLOY OK`, or `SHIP FAILED: ...` / `DEPLOY FAILED: ...`. On failure, read the error, fix what you can, and say what happened.
4. Tell the user the result and to hard-refresh (Ctrl+F5) http://localhost:8080.

Fallback, only if the terminal tool is unavailable or refused: give the single command `& F:\Godot0-city\tools\deploy.ps1` in a fenced block so the user runs it in the in-app terminal.

## Rules
- Port 8080 only. Never use `WEB_PORT` or suggest another port.
- Never touch 8090 or any other project's containers. The only container you may stop is `godot0-city-web-1`.
- Never run `docker compose down`, `docker rm`, `docker system prune`, `docker volume prune` or similar. The only cleanup is `docker image prune -f` (dangling images only), done by the script.
