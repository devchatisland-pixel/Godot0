# Working on Godot city

## Show the work live in the in-app terminal
The user wants to see what is going on, not guess what a background task is doing.

- Every action that changes something or takes time runs in a new tab of the user's Terminal panel
  (`mcp__terminal__run_in_terminal`, a short `title` saying what it is): git commit/push, PR create/merge,
  pulls, Godot import/export, Docker commands, downloads, cleanups.
- No background Bash tasks or hidden runs for that work. Bash stays for quick read-only checks
  (`git status`, `git diff`, `ls`, `curl` on localhost).
- Long or multi-step work goes into a script (`tools/*.ps1`) and the tab runs the script, so one tab shows every step.
- If the tool reports the line was not started (it happens with long argument lists), write the line into a
  one-line wrapper `.ps1` (untracked) and run `& .\wrapper.ps1`; delete it afterwards.
- Watch the tab with `mcp__terminal__read_terminal`, tell the user what it shows, and close finished tabs
  (`mcp__terminal__stop_terminal_tab` with `close: true`) so they do not pile up.
- Never hand commands to the user to copy; only fall back to a single command in a fenced block if the terminal tool is unavailable.

## Shipping and deploying
- Ship (commit, push, PR, merge into `main`): `tools/ship.ps1`, see the `godot-workflow` skill.
- Deploy on http://localhost:8080: the `deploy` skill (`tools/ship.ps1` then `tools/deploy.ps1`, local Godot 4.6.3 export).
- Port 8080 only; never touch other projects' containers (8090 etc.).
