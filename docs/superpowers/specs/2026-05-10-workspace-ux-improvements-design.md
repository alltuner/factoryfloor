# Workspace UX Improvements

## Overview

Two improvements to the Dockyard workspace view:
1. Keyboard-driven split pane — toggle any tab type into a side-by-side split with a single shortcut
2. Info tab git stats — expand the existing git section with worktree and branch metadata

---

## Feature 1: Keyboard-driven split pane

### Summary

The workspace defaults to single-tab view (current behaviour). A new set of Cmd+Shift shortcuts toggles any tab type into a right-side split pane alongside the current primary view. Max two panels at once. The same shortcut collapses the split.

### New keyboard shortcuts

These do not conflict with any existing shortcuts in the app:

| Shortcut | Action |
|---|---|
| Cmd+Shift+Return | Toggle Agent in split pane |
| Cmd+Shift+T | Toggle Terminal in split pane |
| Cmd+Shift+B | Toggle Browser in split pane |

Existing shortcuts (Cmd+Return, Cmd+T, Cmd+B) are unchanged — they open a new tab without splitting.

### Toggle logic

Given a split shortcut is pressed:
- If the target tab type is not currently visible → reuse the most recently active tab of that type (or create a new one if none exists) and show it in the right pane (split view activates)
- If the target tab type is in the RIGHT pane → collapse the right pane, left pane goes full screen
- If the target tab type is in the LEFT pane → collapse the left pane, right pane goes full screen

Only one split at a time (two panels max). No tri-pane or grid view.

### Split pane state

Add to the workstream view model (or TerminalContainerView):
- `splitTab: WorkspaceTab?` — nil means single-tab mode; non-nil is the right-pane tab
- `primaryTab: WorkspaceTab` — the left/full-screen tab (existing selected tab)

When `splitTab` is non-nil, the view renders as an HSplitView: primary on left (default ~60% width, user-resizable), splitTab on right.

### Architecture notes

- `TerminalSurfaceCache` already keeps all terminal surfaces alive in memory. Entering/leaving split is a pure layout change — no terminal processes are created or destroyed.
- The split divider should be draggable (AppKit HSplitView handles this natively).
- Split state is per-workstream and ephemeral (not persisted across app restarts).
- Update `DockyardApp.swift` menu commands, `TerminalContainerView.swift` keyboard handling, `HelpView.swift` shortcut reference, and `README.md` shortcut table.
- Localize any new user-facing strings (en, ca, es, sv).

---

## Feature 2: Info tab git stats — expanded inline

### Summary

Expand the existing git/path section of `WorkstreamInfoView` with additional rows showing worktree and branch metadata. No structural redesign — new rows are inserted inline in the existing grouped-list style (label left, value right, border-bottom separator).

### New rows (inserted between current Branch row and Directory row)

| Label | Value | Colour hint |
|---|---|---|
| Branch | `dy/my-feature` | accent (purple) |
| Ahead | `↑ 4 commits` (vs base branch) | primary text |
| Uncommitted | `2 files` / `Clean` | yellow if >0, muted if 0 |
| Base | `main · branched May 7` | muted |
| Worktree age | `3 days` / `Created today` | primary text |
| Directory | existing row, unchanged | muted + copy btn |

### Data sourcing

All data is derived from shell commands, added to `AppEnvironment` and refreshed on the existing 15-second async cycle:

| Field | Command |
|---|---|
| Commits ahead | `git rev-list --count <baseBranch>..HEAD` |
| Uncommitted files | `git status --porcelain | wc -l` (trimmed) |
| Branch base + date | Stored on `Workstream` as `baseBranch` (already exists); date from `git log --format=%ci <baseBranch>..HEAD | tail -1` |
| Worktree age | Derive from worktree directory creation date via `FileManager.attributesOfItem` (`FileAttributeKey.creationDate`) on `worktreePath` |

### Model changes

Add to `AppEnvironment` (or a new `WorkstreamGitStats` struct keyed by workstream ID):
- `commitsAhead: Int`
- `uncommittedCount: Int`
- `branchCreatedDate: Date?`

`WorkstreamInfoView` reads these from the environment and formats them for display. If a value is unavailable (e.g., no worktree path), the row is omitted rather than showing a zero or error.

### Localisation

All new label strings added to all 4 locale files (en, ca, es, sv).

---

## Out of scope

- Tri-pane or grid layouts
- Persisting split state across restarts
- Any code editor pane (editing stays in terminal tabs via nvim or similar)
- nvim launcher shortcut (saves one command, not worth the complexity)
- Split pane for Info or Environment tabs (these are settings panels, not work surfaces)