# Port Detection: Implementation Plan

## Decision

Use a **bundled launcher binary** (`ff-run`) that wraps the run script,
owns the child process tree, detects listening TCP ports via `libproc`,
and reports results to the app via a state file.

This supersedes the earlier tmux-only and lsof-polling approaches.
The launcher works identically in both tmux and non-tmux modes.

## How it works

```
Terminal shell -> ff-run --workstream-id <uuid> -- <run command>
                    |
                    +-- spawns run command as child process
                    +-- polls child tree for TCP LISTEN ports (libproc)
                    +-- writes state to ~/.config/factoryfloor/run-state/<uuid>.json
                    +-- forwards signals, mirrors exit code
```

The app polls or watches the state file and updates browser targets.

## V1 scope

**In scope:**

- Bundled `ff-run` Swift executable target in project.yml
- Wrap only the Environment tab run script (not setup)
- Native `libproc` port detection (no lsof subprocess)
- State file reporting at `~/.config/factoryfloor/run-state/<uuid>.json`
- Conservative browser retargeting (only default URL or connection error)
- Works in both tmux and non-tmux modes

**Not in scope:**

- Wrapping setup scripts
- Auto-opening browser tabs
- Multi-port heuristics beyond a clear single winner
- HTTP readiness probing
- Remote host / non-localhost detection
- Daemonized background services

## Launcher requirements

The `ff-run` binary must:

- Launch the run command as a child process group
- Keep stdin/stdout/stderr attached (interactive terminal behavior)
- Forward signals (SIGINT, SIGTERM) to the child group
- Poll child process tree for listening TCP ports every 1 second
- Write state file with detected ports
- Exit with the same code as the child process
- Clean up state file on exit

## State file format

```json
{
  "pid": 12345,
  "status": "running",
  "detectedPorts": [5173],
  "selectedPort": 5173,
  "startedAt": "2026-03-17T12:00:00Z"
}
```

Status values: `starting`, `running`, `stopped`, `crashed`.

## Port selection rules

1. If exactly one new listening port appears, select it
2. If multiple appear and `FF_PORT` is among them, select `FF_PORT`
3. Otherwise, report all but don't auto-select

Stabilization: require the same port on 2 consecutive polls before
reporting it as selected (avoids transient bootstrap ports).

## Browser retargeting policy

When a port is selected:

- Retarget browser tabs still on the default `localhost:$FF_PORT` URL
- Retarget tabs showing the connection error for that URL
- Do NOT navigate tabs the user has pointed elsewhere
- Do NOT create new browser tabs
- Update the default URL for new tabs and "Open External Browser"

## App-side changes

- `EnvironmentTabView`: route run command through `ff-run` launcher
- `TerminalContainerView`: store detected port per workstream, feed to browser tabs
- `BrowserView`: accept external retarget when on default URL or error

## File changes

| File | Change |
|------|--------|
| `project.yml` | New `ff-run` executable target |
| `Sources/Launcher/` | New directory for ff-run source |
| `Sources/Models/PortDetector.swift` | App-side state file reader |
| `Sources/Views/EnvironmentTabView.swift` | Build ff-run command |
| `Sources/Views/TerminalContainerView.swift` | Store detected port |
| `Sources/Views/BrowserView.swift` | Accept retarget requests |
| `Tests/` | Port selection rules, retarget policy |

## Open questions

1. **Should ff-run be a separate executable target or a script?**
   Decision: executable. Shell signal forwarding is fragile, and
   libproc inspection requires Swift/C.

2. **State file polling vs FSEvents watching?**
   Decision: FSEvents via `DispatchSource.makeFileSystemObjectSource`.
   Reacts instantly when ff-run writes the file, no polling timer
   needed. Watch the run-state directory for file creation, then
   watch the specific file for writes.

3. **What happens if ff-run crashes?**
   The terminal shows the error, the shell stays alive (initialInput),
   and the user hits Rerun. State file goes stale; app validates PID
   with `kill(pid, 0)` before trusting it. No special recovery needed.

4. **Should the user be able to disable port detection?**
   Not in v1. The feature is passive (only retargets default URLs).
   Add a setting later if users complain.

5. **Timeout?**
   Less critical with FSEvents (no wasted app-side polling). The
   launcher polls libproc every 1s for the first 60 seconds. If no
   port is found, drop to every 60s as a background safety net.
   Once a port is selected and stable, scanning stops entirely.

## Effort estimate

- Launcher binary (process management, libproc, state file): 1-2 days
- App integration (state reader, browser retarget): 1 day
- Testing: half day
- **Total: ~3 days**
