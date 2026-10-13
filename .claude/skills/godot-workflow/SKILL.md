---
name: godot-workflow
description: Use for ANY work on this Godot city project (editing scenes/scripts/assets, fixing bugs, adding buildings, testing). Prefer the godot MCP tools over classic CLI commands, then ship the change to main automatically.
---

# Godot workflow (always)

## 1. Use the godot MCP tools first (faster than CLI)
- Inspect: `get_project_info`, `list_projects`, `get_godot_version`.
- Scenes/nodes: `create_scene`, `add_node`, `save_scene`, `load_sprite`, `export_mesh_library`.
- Validate a change: `run_project` then `get_debug_output` (look for parse/script errors), then `stop_project`. Use `launch_editor` only if the user wants the editor.
- After moving/renaming resources: `get_uid` / `update_project_uids`.
- Fall back to the Godot console exe / shell only when no MCP tool covers it (e.g. `tools/*.gd` batch scripts, tests in `tests/`).

## 2. Ship automatically when a change is finished and validated
Do this without waiting for the user to ask, live in the user's Terminal panel (never via Bash or a background task, so the user sees every step):
run `mcp__terminal__run_in_terminal` with cwd = the session's checkout, title `ship`, command
`& .\tools\ship.ps1 -Title "<clear commit/PR title>" -Paths <file1>,<file2> -NoDeploy`
(`-Paths` = only the change's files, never `FREEMODELS/_incoming/`). It commits, pushes, opens the PR into `main`, merges once checks pass, and pulls `F:/Godot0-city` (ff-only).
Watch it with `mcp__terminal__read_terminal` until `SHIP OK` or `SHIP FAILED: ...`.
Then tell the user it is on `main` and ready for "deploy" (if the user already asked to deploy, use the deploy skill instead: same script without `-NoDeploy`).
Never push anywhere except this repo's origin; never force-push; never rewrite main.
