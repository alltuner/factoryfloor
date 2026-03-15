# TODO

## Priority (next session)
- [ ] Archive warning: warn if worktree has uncommitted changes before archiving
- [ ] Workstream sorting in project view (by name or recent use toggle)
- [ ] Setup scripts: run commands when a worktree is created (e.g., npm install, pip install)
- [ ] Run scripts: configurable ways to start dev servers (multiple per project)
- [ ] Teardown scripts: cleanup commands when archiving a workstream
- [ ] Sidebar shows branch name per workstream (refreshed periodically)

## Pre-release
- [ ] Choose final app name (currently "ff2" is a working name)
- [ ] Update bundle ID (`com.ff2.app` in project.yml), URL scheme, AppConstants
- [ ] Build and ship a standalone CLI binary (like `code` for VS Code)
- [ ] Code signing and notarization for distribution
- [ ] App icon
- [ ] Credits: Poblenou skyline from alltuner.com, All Tuner Labs logo in help view

## Features
- [ ] Sidebar visual polish (custom styling beyond default SwiftUI)
- [ ] Split panes within a workstream
- [ ] Reorder projects via drag-and-drop in sidebar
- [ ] External Chrome integration: launch with --remote-debugging-port for WebMCP/CDP
- [ ] PR management: create and manage PRs from workstreams (currently view-only)
- [ ] Extract env var injection logic to a shared module

## Terminal
- [ ] Sidebar toggle animation still causes minor flicker at the end
- [ ] Occlude non-visible terminal surfaces to save GPU (reverted, needs careful timing)

## Infrastructure
- [ ] Auto-update mechanism (Sparkle or similar)
- [ ] Crash reporting
- [ ] Move persistence from UserDefaults to a proper file (for larger state)

## Localization
- [ ] Add more translations (copy en.lproj to xx.lproj, translate strings)
- [ ] New strings from recent features need translation in ca, es, sv

## Done
- [x] Embedded Ghostty terminals (Metal GPU-rendered via libghostty)
- [x] Project and workstream management with sidebar tree
- [x] Git worktrees for workstreams (branch off default branch)
- [x] .env/.env.local symlinks in worktrees
- [x] Tmux mode for session persistence across app restarts (dedicated socket)
- [x] Claude session resume via --session-id/--resume
- [x] Auto-respawn on process exit (tmux pane-died hook)
- [x] Auto-rename branch via system prompt injection
- [x] Per-workstream permission mode (bypass prompts, context menu on +)
- [x] Agent Teams setting (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
- [x] --teammate-mode tmux flag
- [x] Deterministic port allocation per workstream (FF_PORT env var)
- [x] Four workstream tabs: Info, Coding Agent, Terminal, Browser
- [x] Embedded WKWebView browser with nav bar, home button
- [x] Info tab with rendered README.md and CLAUDE.md (MarkdownView SPM package)
- [x] GitHub integration: repo info, open PRs, branch PR status (via gh CLI)
- [x] Context-sensitive Cmd+0-9 shortcuts (project view: workstreams, workstream: tabs)
- [x] Cmd+Shift+[/] tab cycling
- [x] Cmd+Shift+O external browser, Cmd+Shift+E external terminal
- [x] Ctrl+Cmd+S sidebar toggle
- [x] Esc closes settings/help
- [x] Help view with grouped shortcuts, credits, Poblenou skyline
- [x] Settings: environment detection, tmux, bypass, teams, auto-rename, appearance, language, base dir, branch prefix, external apps, danger zone
- [x] Project overview with editable alias, git/GitHub info, workstream list
- [x] Drag-and-drop directories to sidebar
- [x] ff2:// URL scheme for single-instance behavior
- [x] CLI launch with directory argument
- [x] Auto-generated workstream names (operation-adjective-component)
- [x] Async git repo info, path validity, GitHub data with periodic refresh
- [x] Auto-remove projects with missing directories
- [x] Worktree path validation with visual feedback (warning icon + strikethrough)
- [x] Localization: en, ca, es, sv
- [x] Performance: cached sorted IDs, O(1) lookups, debounced saves, deferred init, surface prewarm
- [x] Terminal resize flicker fix, async archive operations
- [x] CommandBuilder for clean shell command composition
- [x] Poblenou skyline as SwiftUI Shape in help and empty state
- [x] CLAUDE.md with comprehensive development workflow docs

## Probably not needed
- [ ] Claude Agent SDK integration (TypeScript): CLI + tmux + session-id covers our needs
