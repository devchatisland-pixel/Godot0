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
Do this without waiting for the user to ask:
1. Commit on the current worktree branch (clear message).
2. Push the branch.
3. Open a PR into `main` (`gh pr create` or github MCP), then merge it once checks pass.
4. Retrieve it locally: `git -C F:/Godot0-city pull --ff-only` (never force; if the main checkout is dirty or not fast-forwardable, stop and tell the user).
Then tell the user it is on `main` and ready for "deploy".
Never push anywhere except this repo's origin; never force-push; never rewrite main.
