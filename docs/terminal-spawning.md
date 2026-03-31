# Terminal Spawning Architecture

How Factory Floor spawns terminals, delivers commands to Ghostty, and manages
the coding agent, setup scripts, and run scripts in both tmux and non-tmux modes.

## How Ghostty Receives a Command

`TerminalView` (Sources/Terminal/TerminalView.swift) creates a
`ghostty_surface_config_s` struct via the C API and sets three key fields:

- `config.command` -- the shell command string Ghostty will spawn
- `config.working_directory` -- the worktree path
- `config.env_vars` / `config.env_var_count` -- environment variables

It then calls `ghostty_surface_new(app, &cfg)` to create the terminal surface.
The command is passed as raw shell syntax; Ghostty's platform layer handles
execution.

## Environment Variables

`WorkstreamEnvironment.variables()` (Sources/Models/WorkstreamEnvironment.swift)
builds the environment injected into every workstream terminal:

| Variable | Value |
|----------|-------|
| `FF_PROJECT` | Project name |
| `FF_WORKSTREAM` | Workstream name |
| `FF_PROJECT_DIR` | Project root directory |
| `FF_WORKTREE_DIR` | Worktree / working directory |
| `FF_PORT` | Port number derived from working directory |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` if agent teams flag is on |

For non-tmux terminal tabs, `TMUX` and `TMUX_PANE` are explicitly cleared to
prevent session inheritance from a parent tmux.

## The Three Terminal Types

### 1. Coding Agent (`.agent` tab)

`buildClaudeCommand()` in TerminalContainerView constructs the command:

- `claude --resume <sessionID>` (or `--session-id` for a fresh session)
- `--teammate-mode tmux` if tmux mode is enabled
- `--dangerously-skip-permissions` if bypass flag is set
- `CommandBuilder.withFallback()` provides graceful fallback from resume to fresh

### 2. Setup Script

Loaded from `.factoryfloor.json` via `ScriptConfig.load()`. Wrapped as:

```
shell -lic 'setup-command; printf "\nSetup completed in this terminal.\n"'
```

Preloaded before the UI is visible via `preloadSurfaces()`.

### 3. Run Script

Also from `.factoryfloor.json`. Only starts when the user clicks "Start".

If the ff-run launcher is available, the command is wrapped as:

```
ff-run --workstream-id <uuid> -- shell -lic 'command'
```

The launcher `exec`s the user's command (preserving PID and PTY) while forking a
monitor child that polls for listening TCP ports via `proc_*` APIs and writes
state to `~/Library/Caches/factoryfloor/run-state/<workstream-id>.json`.

## Tmux Mode vs Non-Tmux Mode

### Non-tmux

The command goes straight to Ghostty. The terminal dies with the surface.

### Tmux

`TmuxSession.wrapCommand()` (Sources/Models/TmuxSession.swift) wraps everything:

```
shell -lc "exec sh -c '
  (tmux -L factoryfloor start-server;
   tmux -L factoryfloor source-file /path/to/tmux.conf;
   tmux -L factoryfloor set-hook -gu pane-died);
  exec tmux -L factoryfloor new-session -A -s <session> [-e VAR=VAL ...] <command>
'"
```

Key details:

- **Dedicated socket** `-L factoryfloor` isolates from the user's tmux.
- **Session naming**: `factoryfloor/project/workstream/role` where role is
  `agent`, `setup`, or `run`.
- **`new-session -A`** attaches to an existing session if present, providing
  persistence across app restarts.
- **Env vars** are passed via `-e` flags on the tmux command.
- **Config**: no status bar, no prefix key, mouse passthrough,
  `remain-on-exit on`, 50k line scrollback.

## Full Wrapping Chain

Worst case for a run script with tmux (3 layers):

```
User clicks "Start"
  -> runScriptCommand():
       "ff-run --workstream-id UUID -- shell -lic '...'"
  -> TmuxSession.wrapCommand():
       "shell -lc 'exec sh -c ...tmux new-session...'"
  -> TerminalView(command: finalCommand)
  -> ghostty_surface_config.command = finalCommand
  -> Ghostty spawns shell
```

## Surface Lifecycle

Surfaces are cached by UUID in `TerminalSurfaceCache`. IDs are deterministic:

| Type | Surface ID |
|------|------------|
| Agent | workstreamID directly |
| Setup | `derived(workstreamID, "env-setup-0")` |
| Run | `derived(workstreamID, "env-run-{generation}")` |
| Terminal tabs | `derived(workstreamID, "terminal-{count}")` |

Run script generation increments on restart, forcing a new surface. Agent
surfaces auto-respawn on close; terminal tabs close and remove themselves.

## Workstream Creation to Running Terminal

1. User clicks "+" in sidebar -> `addWorkstream()` creates git worktree,
   generates name, creates `Workstream` model.
2. `ContentView` sets selection to the new workstream, renders
   `TerminalContainerView`.
3. `TerminalContainerView.onAppear` loads `ScriptConfig`, builds the claude
   command, computes env vars, restores or initializes tabs.
4. `preloadSurfaces()` creates `TerminalView` instances for agent and setup
   (if configured) before the UI is visible.
5. `SingleTerminalView` (NSViewControllerRepresentable bridge) adds the
   `TerminalView` as a subview, constrains it to fill, and optionally makes
   it first responder.
6. Ghostty renders to the view's CALayer and processes input events forwarded
   by `TerminalView`.

## Key Files

| File | Role |
|------|------|
| `Sources/Terminal/TerminalApp.swift` | Ghostty app lifecycle, runtime callbacks |
| `Sources/Terminal/TerminalView.swift` | NSView hosting Ghostty surface, input handling |
| `Sources/Views/Workspace/TerminalContainerView.swift` | Tab management, surface cache, command building |
| `Sources/Models/CommandBuilder.swift` | Shell command escaping and construction |
| `Sources/Models/TmuxSession.swift` | Tmux session naming, command wrapping, config |
| `Sources/Models/ScriptConfig.swift` | Loads setup/run/teardown from .factoryfloor.json |
| `Sources/Views/Workspace/EnvironmentTabView.swift` | UI for setup/run scripts, launch logic |
| `Sources/Models/RunLauncher.swift` | ff-run binary discovery and command wrapping |
| `Sources/Launcher/main.swift` | Port monitor implementation |
| `Sources/Models/WorkstreamEnvironment.swift` | Environment variable injection |
