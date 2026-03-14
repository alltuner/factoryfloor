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

## Terminal
- [x] Terminal resize flicker on session restart
- [ ] Sidebar toggle animation still causes minor flicker at the end
- [ ] Occlude non-visible terminal surfaces to save GPU (reverted, needs careful timing with initial render)

## Infrastructure
- [ ] Auto-update mechanism (Sparkle or similar)
- [ ] Crash reporting
- [ ] Move persistence from UserDefaults to a proper file (for larger state)
