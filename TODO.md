# TODO

## Pre-release

- [x] App screenshots on website (agent, environment, info, terminal, browser, project)

## Post-release

- [ ] Auto-update mechanism (Sparkle): in-app update for direct DMG users

## Bugs

- [x] Branch name doesn't appear in sidebar after workstream creation until the 15s refresh timer fires. Fixed: call `refreshPathValidity` immediately in the `.workstreamWorktreeReady` handler.

## UI improvements

- [x] Sidebar workstream rows: removed repetitive terminal icons, kept warning icon only for invalid paths
- [x] Sidebar workstream subtext: show PR title (#number) when available, fall back to branch name only when it differs from the workstream name

## Future

- [ ] External Chrome integration: launch with --remote-debugging-port for WebMCP/CDP
- [ ] PR management: create and manage PRs from workstreams (currently view-only)
- [ ] Horizontal terminal splits within a tab (ghostty C API supports splits)
- [ ] System notifications when agent needs attention (bell/urgency from Ghostty)

## Done

- [x] Embedded Ghostty terminals (Metal GPU-rendered via libghostty)
- [x] Project and workstream management with sidebar tree
- [x] Git worktrees for workstreams (branch off default branch)
- [x] .env/.env.local symlinks in worktrees (guarded by setting)
- [x] Tmux mode for Coding Agent session persistence
- [x] Claude session resume via --session-id/--resume
- [x] Auto-respawn agent on process exit (tmux pane-died hook)
- [x] Auto-rename branch via --append-system-prompt
- [x] Per-workstream permission mode (bypass prompts, context menu on +)
- [x] Agent Teams setting (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
- [x] Deterministic port allocation per workstream (FF_PORT env var, DJB2 hash)
- [x] Dynamic workspace tabs (Info + Agent + Environment, Terminal/Browser on demand)
- [x] Terminal tabs auto-close on shell exit, agent respawns
- [x] Multi-terminal support with proper Ghostty focus management
- [x] Embedded WKWebView browser with nav bar, loading indicator
- [x] Cmd+L address bar focus, auto-focus on new browser
- [x] PR badge in workspace toolbar (links to GitHub PR)
- [x] Info tab with README.md, CLAUDE.md, AGENTS.md (cmark-gfm WKWebView, skip files < 20 bytes)
- [x] Doc tabs in project overview (shared DocFile/DocTabButton)
- [x] GitHub integration: repo info, open PRs, branch PR status (via gh CLI)
- [x] Keyboard shortcuts: all documented in HelpView, README, AGENTS.md, and website
- [x] Help view with app icon, skyline, shortcuts, credits, sponsor/bug/feature links
- [x] Settings: environment, CLI install (auto-hidden), tmux, bypass, teams, auto-rename, appearance, language, base dir, branch prefix, external apps, bleeding edge, danger zone
- [x] Project overview with editable name, git info, GitHub info, worktree list with prune, doc tabs
- [x] Workstream info with project icon, branch copy, directory, PR status, scripts, docs
- [x] Drag-and-drop directories to sidebar
- [x] factoryfloor:// URL scheme for single-instance behavior
- [x] CLI launcher (ff) installed via Homebrew cask binary directive
- [x] Auto-generated workstream names (operation-adjective-component)
- [x] Workstream name syncs from branch rename (every 15s)
- [x] Sidebar state persisted across restarts (JSON files in ~/.config/factoryfloor/)
- [x] Async git repo info, path validity, branch names (parallelized via TaskGroup)
- [x] Auto-remove projects with missing directories (with user notification)
- [x] Worktree path validation with visual feedback
- [x] Archive warning for uncommitted changes
- [x] Workstream sorting in project view (recent / A-Z)
- [x] Localization: en, ca, es, sv (all strings translated)
- [x] Script config: .factoryfloor.json
- [x] Environment tab: setup (auto) / run (on-demand) with Rebuild and Start/Rerun shortcuts
- [x] Port detection: ff-run launcher with libproc process tree scanning and auto browser retarget
- [x] Tmux session restore for run scripts on app relaunch
- [x] Preload agent and setup terminals in background
- [x] Occlude non-visible terminal surfaces (ghostty_surface_set_occlusion)
- [x] Update notification: versions.json check + sidebar badge + /get page
- [x] App icon with Poblenou skyline
- [x] Project icon detection (icon.svg, icon.png, logo.svg, logo.png)
- [x] Ghostty submodule pinned to v1.3.1, weekly CI compatibility test
- [x] Code signing, notarization, release-please, CI pipeline (security hardened)
- [x] Homebrew tap (alltuner/homebrew-tap) with cask and CLI binary
- [x] Website: Hugo + Tailwind, i18n (4 langs), sponsor page, privacy, SEO, OG image, /get page
- [x] Distribution: docs/distribution.md with automated versions.json in release workflow
- [x] Onboarding view with prerequisites, getting started, key concepts
- [x] Sentry crash reporting (EU, no PII, environment/version tags)
- [x] Swift 6 strict concurrency migration
- [x] Security: WKWebView JS disabled, shell-escape tmux, surface destroy, git flag injection, .env symlink validation
- [x] Accessibility: labels, focus rings, keyboard-reachable hover actions
- [x] Code quality: dedup, parallelized git, cached state, consolidated timers, error propagation
- [x] Error feedback: worktree creation, non-git dir, ghostty init, project removal, Claude not found
- [x] Fix: terminal mouse selection coordinates, env script lifecycle, proc_listchildpids count
- [x] Restore full app state on launch, right-click sidebar menus, drag-and-drop tab reorder
