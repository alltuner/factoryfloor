# Terminal Resilience Design

Design doc for improving error handling, recovery, and diagnostics across
the terminal spawning stack.

## Problem

The terminal spawning pipeline (ghostty surface, tmux wrapping, ff-run launcher)
has multiple layers that independently swallow errors. When something goes wrong,
the user sees a blank or broken terminal with no diagnostics and no recovery path.

## Goals

- Failures are visible to the user, not silent
- The user can retry or recover without restarting the app
- Diagnostics are available for debugging (logs, error messages)
- Orphaned resources (tmux sessions, zombie processes) are cleaned up

## Non-goals

- Automatic retry without user awareness
- Changing the fundamental layering (ghostty -> tmux -> ff-run)

---

## 1. Surface creation failure recovery

**Current behavior:** `ghostty_surface_new` returns nil, TerminalView logs and
continues with a nil surface. Tab appears blank forever.

**Proposed:**
- Make TerminalView.init return nil (failable init) or use a factory method
  returning `Result<TerminalView, Error>`
- Callers (preloadSurfaces, handleSurfaceClosed) check the result
- Tab UI shows an error state with a retry button
- Error state includes the failed command for debugging

**Open questions:**
- Can ghostty_surface_new fail transiently (worth auto-retrying once)?
- Should we show a terminal-styled error or a SwiftUI overlay?

---

## 2. Surface health check

**Current behavior:** No validation that the spawned process is alive after
surface creation succeeds.

**Proposed:**
- After surface creation, start a short timer (~2s)
- If the surface's child process exits within that window, treat it as a
  launch failure
- Transition tab to error state with the exit code and any captured output
- This catches failures in any wrapping layer without instrumenting each one

**Open questions:**
- Does ghostty expose child process PID or exit status via the C API?
- If not, can we detect "surface closed immediately" via the existing
  close notification?

---

## 3. Tmux error reporting

**Current behavior:** `start-server`, `source-file`, and `set-hook` all use
`|| true` with stderr redirected to /dev/null. Broken config or stale socket
produces zero diagnostics.

**Proposed:**
- Drop `|| true` from `source-file` (bad config should be a hard error)
- Keep `|| true` on `start-server` (expected to fail if already running)
- Redirect stderr to a per-session log file in the cache directory
- On session cleanup, remove the log file
- Surface errors in a "tmux diagnostics" view or in the terminal error state

**Proposed:** Add `killAllSessions()` via `tmux -L factoryfloor kill-server`
on app termination to prevent orphaned sessions.

**Open questions:**
- Is `source-file` failure recoverable, or should it block the session?
- Should we add a tmux health check (periodic `has-session`)?

---

## 4. ScriptConfig error surfacing

**Current behavior:** `try?` everywhere. Malformed `.factoryfloor.json` silently
produces empty config. User thinks scripts aren't configured.

**Proposed:**
- Replace `try?` with `do/catch` in load methods
- Store parse errors in ScriptConfig (e.g., `let loadError: String?`)
- Environment tab shows the error inline when present
- Log the error for CLI/console debugging

**Open questions:**
- Should we validate the JSON schema beyond basic parsing?
- Show error as a banner, inline text, or toast?

---

## 5. CommandBuilder fallback diagnostics

**Current behavior:** `withFallback()` redirects primary command's stderr to
/dev/null. If `claude --resume` fails, the user silently gets a fresh session.

**Proposed:**
- Redirect stderr to a temp file instead of /dev/null
- If the fallback fires, print a diagnostic line to the terminal:
  `"[Factory Floor] Session resume failed, starting fresh. See /tmp/ff-... for details"`
- Clean up temp files on session end

**Open questions:**
- Is printing to the terminal before the fallback command runs feasible
  within a single shell pipeline?
- Alternative: write to a known location and surface in the UI

---

## 6. ff-run launcher validation

**Current behavior:** If the ff-run binary is missing, the command string
references a nonexistent path. Shell exits immediately.

**Proposed:**
- Validate binary exists and is executable in `RunLauncher.executableURL()`
- If missing, fall back to running the command directly (no port detection)
- Log a warning visible in the Environment tab
- Port detection gracefully degrades (browser tab shows "no port detected")

---

## 7. Respawn race condition

**Current behavior:** `handleSurfaceClosed` reads params, removes old surface,
creates new surface, and re-inserts. Not atomic. Concurrent calls can create
duplicates or lose the surface permanently.

**Proposed:**
- Add a `respawning: Set<UUID>` guard to TerminalSurfaceCache
- Check and insert into the set before starting respawn
- Remove from set after completion (success or failure)
- If respawn fails, transition to error state instead of silently dropping

---

## Implementation priority

| Change | Effort | Impact | Priority |
|--------|--------|--------|----------|
| Surface creation failure recovery | Medium | Critical | P0 |
| Surface health check | Medium | Critical | P0 |
| ScriptConfig error surfacing | Small | High | P1 |
| Respawn race condition | Small | High | P1 |
| Tmux error reporting | Small | High | P1 |
| ff-run launcher validation | Small | Medium | P2 |
| CommandBuilder fallback diagnostics | Small | Medium | P2 |

---

## Notes

<!-- Working area for ideas, discussion, alternatives -->
