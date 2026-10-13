---
name: deploy
description: Use when the user says "deploy" on the Godot city project. Fully automated, no commands handed to the user - ships any pending change to main (commit/push/PR/merge), then runs tools/deploy.ps1 in the user's Terminal panel so they watch the live build on 8080 (pull, stop old container, rebuild, prune leftover images).
---

# Deploy (local, port 8080 only, fully automated)

Site: http://localhost:8080, container `godot0-city-web-1` (service `web`), built from the main checkout `F:/Godot0-city`.

Do every step yourself. Never reply with commands for the user to copy and run.

## Steps
1. **Ship pending work to main.** In the session's checkout, if there are uncommitted changes or commits not yet on `origin/main`:
   commit (clear message), push the branch, open a PR into `main` with `gh pr create`, merge it with `gh pr merge --merge` once checks pass (no checks = merge right away).
   Never force-push, never push to main directly. Only stage files that belong to the change (not `FREEMODELS/_incoming/`).
   If nothing is pending, skip.
2. **Run the deploy in the user's Terminal panel** with the `mcp__terminal__run_in_terminal` tool (load it via ToolSearch if deferred):
   - command: `& F:\Godot0-city\tools\deploy.ps1`
   - cwd: `F:\Godot0-city`, title: `deploy 8080`
   The script pulls `main` (ff-only), stops `godot0-city-web-1`, runs `docker compose up --build -d web` with live output, then `docker image prune -f` to remove the untagged images left by previous builds.
   Run it in the terminal (not Bash): the user sees the live output, and it is not blocked by the worktree sandbox.
3. **Watch it finish** with `mcp__terminal__read_terminal` (tab_id from step 2, `wait_for_output_ms` up to ~120000, repeat). The web export takes a few minutes.
   Done when it prints `DEPLOY OK` or `DEPLOY FAILED: ...`. On failure, read the error, fix what you can, and say what happened.
4. Tell the user the result and to hard-refresh (Ctrl+F5) http://localhost:8080.

Fallback, only if the terminal tool is unavailable or refused: give the single command `& F:\Godot0-city\tools\deploy.ps1` in a fenced block so the user runs it in the in-app terminal.

## Rules
- Port 8080 only. Never use `WEB_PORT` or suggest another port.
- Never touch 8090 or any other project's containers. The only container you may stop is `godot0-city-web-1`.
- Never run `docker compose down`, `docker rm`, `docker system prune`, `docker volume prune` or similar. The only cleanup is `docker image prune -f` (dangling images only), done by the script.
