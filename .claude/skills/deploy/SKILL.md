---
name: deploy
description: Use when the user says "deploy" on the Godot city project. Makes sure the change is merged and pulled, stops the old web container on 8080, then gives the user the 2 commands to rebuild on 8080 only.
---

# Deploy (local, port 8080 only)

Site: http://localhost:8080, container `godot0-city-web-1` (service `web`), built from the main checkout `F:/Godot0-city`.

## Steps (do 1-3 yourself, then show 4)
1. Verify the change is merged to `main` (see godot-workflow skill step 2). If not, ship it first (commit/push/PR/merge).
2. Make sure the main checkout is current: `git -C F:/Godot0-city pull --ff-only`.
3. Stop the old version still running on 8080: `docker stop godot0-city-web-1` (that container only; skip if already stopped). Confirm 8080 is free with `docker ps`.
4. Reply with these two commands, each in its own fenced `bash` block, no `$` prompt, then run nothing else:

```bash
git -C F:/Godot0-city pull
```

```bash
cd F:/Godot0-city && docker compose up --build -d web
```

Note: the web export takes a few minutes; hard-refresh (Ctrl+F5) afterwards.

## Rules
- Port 8080 only. Never use `WEB_PORT` or suggest another port.
- Never touch 8090 or any other project's containers. The only container you may stop is `godot0-city-web-1`.
- Never run `docker compose down`, `docker rm`, `docker system prune` or similar.
- The user runs the final build commands themselves.
