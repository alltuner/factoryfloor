# TODO

## Pre-release
- [ ] Choose final app name (currently "ff2" is a working name)
- [ ] Update bundle ID (`com.ff2.app` in project.yml)
- [ ] Update URL scheme (`ff2://` in Info.plist) to match final name
- [ ] Build and ship a standalone CLI binary (like `code` for VS Code)
- [ ] Code signing and notarization for distribution
- [ ] App icon

## Features
- [ ] Sidebar visual polish (custom styling beyond default SwiftUI)
- [ ] Split panes within a workstream
- [ ] Rename projects and workstreams inline
- [ ] Reorder projects via drag-and-drop in sidebar
- [ ] Keyboard shortcuts for switching between projects/workstreams (Cmd+1, Cmd+2, etc.)
- [ ] External Chrome integration: launch Chrome with --remote-debugging-port, connect via CDP for WebMCP/Claude browser interaction
- [ ] Setup scripts: run commands when a worktree is created (e.g., npm install, pip install)
- [ ] Run scripts: configurable ways to start dev servers, build, or run the app (multiple per project)
- [ ] Teardown scripts: cleanup commands when archiving a workstream
- [ ] PR management: create, view, and manage pull requests from workstreams
- [ ] GitHub integration: link workstreams to issues/PRs, show status
- [ ] Branch renaming: rename worktree branches based on the task at hand

## Terminal
- [x] Terminal resize flicker on session restart
- [ ] Sidebar toggle animation still causes minor flicker at the end
- [ ] Occlude non-visible terminal surfaces to save GPU (reverted, needs careful timing with initial render)

## Infrastructure
- [ ] Auto-update mechanism (Sparkle or similar)
- [ ] Crash reporting
- [ ] Move persistence from UserDefaults to a proper file (for larger state)
- [x] Settings panel

## Localization
- [x] Extract all user-facing strings to Localizable.strings
- [ ] Add translations (copy en.lproj to xx.lproj, translate strings)

## Probably not needed
- [ ] Claude Agent SDK integration (TypeScript): would give programmatic session control, but replaces the full CLI TUI we get for free. Only makes sense if building a custom chat UI, orchestrating multiple agents, or showing conversation metadata in the sidebar. The CLI + tmux + session-id approach covers our needs.
