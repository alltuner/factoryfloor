# TODO

## Security

- [x] Pin third-party CI actions to commit SHAs (supply chain protection)
- [x] CI notarization: use keychain profile instead of passing Apple password as CLI arg
- [x] Scope CI permissions per job (release-please: contents+PRs, build: contents only)
- [x] GitOperations.sanitize: strip leading `-` to prevent git flag injection
- [x] .env symlink: validate source is a regular file, not itself a symlink to sensitive data
- [x] Remove website/node_modules from repo, add to .gitignore, install via bun in CI

## Bugs

- [x] BrowserView: "Press Cmd+Shift+B to retry" hint is wrong (removed misleading hint and dead notification)
- [x] Settings/Help persisted as selection: app reopens to Settings if quit while in Settings (fixed)
- [x] Detached HEAD inconsistency: normalize "HEAD" to nil so all views show "detached"
- [x] Path collision: worktree names differing only by `/` vs `-` (now uses `--` for `/`)
- [x] Surface cleanup in removeWorkstreamSurfaces (now iterates until no more matches instead of hard cap)

## UX

- [x] Show error feedback when worktree creation fails (alert instead of silent broken workstream)
- [x] Show install prompt when Claude CLI is not found (instead of plain shell)
- [ ] Setup script: log output or show status instead of routing to /dev/null and ignoring exit code
- [x] Notify user when a project directory is removed from disk (alert with project names)
- [x] Onboarding: prerequisites with live status, getting started steps, key concepts
- [ ] Execute the `run` script from .factoryfloor.json (currently loaded and displayed but never run)
- [x] Show error dialog when ghostty_init fails (NSAlert instead of fatalError)
- [x] ToolRow: text already shown alongside color dot (no change needed)
- [x] Add copy-branch-name button alongside copy-path in workstream info header

## Accessibility

- [x] Add accessibilityLabel/accessibilityHint to all interactive elements
- [x] Make hover-only actions (archive, delete, add) visible via opacity when not hovered
- [x] Restore focus rings on .buttonStyle(.plain) buttons (.borderless) for keyboard navigation

## Code Quality

- [x] Extract duplicated abbreviatePath into a shared String extension (PathUtilities.swift)
- [x] Remove duplicated performArchive logic between ContentView and ProjectSidebar
- [x] bleedingEdge setting: intentionally kept for future auto-update (Sparkle) channel selection
- [x] Remove dead retryBrowser notification (declared and observed but never posted)
- [x] ToolStatus.detect: remove misleading async signature (contains no await)
- [x] Localization: add missing strings for Settings sections, HelpView, BrowserView error UI, ProjectOverviewView
- [x] Remove stale unused keys from Localizable.strings files (already cleaned)
- [x] surfaceRegistry thread safety: action_cb runs on main thread, deinit removal dispatched to main
- [x] Fix derivedUUID misleading comment (says SHA-256 but uses simple byte folding)
- [x] Cache claudeCommand computed property (builds CommandBuilder on every render)
- [x] Consolidate polling timers (PR refresh moved to AppEnvironment, single 15s timer)
- [x] Parallelize refreshPathValidity git calls (TaskGroup)

## Future

- [ ] Swift 6 migration (strict concurrency)
- [ ] External Chrome integration: launch with --remote-debugging-port for WebMCP/CDP
- [ ] PR management: create and manage PRs from workstreams (currently view-only)
- [ ] Auto-update mechanism (Sparkle or similar)
- [ ] Crash reporting
- [x] Move persistence from UserDefaults to JSON files (~/.config/factoryfloor/) with auto-migration
- [ ] Horizontal terminal splits within a tab (ghostty C API supports splits via action_cb, but surface lifecycle needs investigation)
- [ ] Preload Coding Agent terminal in background so it's ready when the user switches from Info tab
- [ ] Drag-and-drop to reorder tabs
- [ ] Show project icon in info pages if found in a well-known location (e.g., icon.png, .github/icon.png)
- [ ] Pin ghostty submodule update to CI (auto-test against new Ghostty releases)
- [ ] Occlude non-visible terminal surfaces to save GPU (needs careful timing)
- [ ] System notifications when agent needs attention (bell/urgency from Ghostty)
- [x] OG image: branded banner with app name, logo, and Poblenou skyline
- [ ] Restore full app state on launch (active tab within workstream; sidebar selection and expanded state already persisted)

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
- [x] Deterministic port allocation per workstream (FF_PORT env var)
- [x] Dynamic workspace tabs (Info + Agent always, Terminal/Browser on demand)
- [x] Terminal tabs auto-close on shell exit, agent respawns
- [x] Multi-terminal support with proper Ghostty focus management
- [x] Embedded WKWebView browser with nav bar, loading indicator
- [x] Cmd+L address bar focus, auto-focus on new browser
- [x] PR badge in workspace toolbar (links to GitHub PR)
- [x] Info tab with README.md, CLAUDE.md, AGENTS.md (pinned header, scrollable docs)
- [x] GitHub integration: repo info, open PRs, branch PR status (via gh CLI)
- [x] Keyboard shortcuts: Cmd+Return (agent), Cmd+I (info), Cmd+T (terminal), Cmd+B (browser), Cmd+W (close tab), Cmd+1-9 (switch tabs), Ctrl+1-9 (switch workstreams), Cmd+Shift+[/] (cycle), Cmd+/ (help)
- [x] Cmd+Shift+O external browser, Cmd+Shift+E external terminal
- [x] Ctrl+Cmd+S sidebar toggle, Esc closes settings/help
- [x] Cmd+W closes tab (overrides macOS window close)
- [x] Help view with app icon, skyline, shortcuts, credits, sponsor link
- [x] Settings: environment, CLI install, tmux, bypass, teams, auto-rename, appearance, language, base dir, branch prefix, external apps (with icons), bleeding edge, danger zone
- [x] Project overview with editable name, centered header, directory with copy/terminal icons, git info, GitHub info, worktree list with prune
- [x] Workstream info with pinned header (project name, workstream name, branch, directory), PR status, scripts, scrollable docs
- [x] Drag-and-drop directories to sidebar
- [x] factoryfloor:// URL scheme for single-instance behavior
- [x] CLI launcher (ff) with install from Settings
- [x] Auto-generated workstream names (operation-adjective-component)
- [x] Workstream name syncs from branch rename (every 15s)
- [x] Sidebar state persisted across restarts (selection + expanded)
- [x] Async git repo info, path validity, branch names with periodic refresh
- [x] Auto-remove projects with missing directories
- [x] Worktree path validation with visual feedback
- [x] Archive warning for uncommitted changes
- [x] Workstream sorting in project view (recent / A-Z)
- [x] Sidebar branch names per workstream
- [x] Sidebar credit line with sponsor link
- [x] Localization: en, ca, es, sv (all strings translated)
- [x] Script config: .factoryfloor.json with fallback to emdash/conductor/superset
- [x] Setup script runs in background on workstream creation
- [x] Teardown script runs before worktree removal on archive
- [x] CommandBuilder with proper shell quoting (25 tests)
- [x] App icon with Poblenou skyline
- [x] Rename to Factory Floor (bundle ID, URL scheme, config, all references)
- [x] Ghostty submodule pinned to v1.3.1
- [x] Bridging header moved to Resources/
- [x] Code signing and notarization (scripts/release.sh)
- [x] Release-please for automated versioning
- [x] MIT license
- [x] README with marketing-first layout
- [x] Website: Hugo + Tailwind, i18n (4 languages), language switcher, skyline, sponsor page, open source section, Umami analytics, canonical/hreflang SEO
- [x] GitHub Pages deploy workflow
- [x] GitHub repo (alltuner/factoryfloor, public, topics, description)
- [x] Distribution guide (docs/distribution.md)
- [x] Debug builds: different icon and bundle ID so debug/release can run in parallel
- [x] Markdown info view: cmark-gfm WKWebView renderer with full HTML support
- [x] Confirm before quit (Cmd+Q) when workstreams are active
- [x] Browser tab: show page title in tab label
- [x] Terminal tab: show running command in tab label (via ghostty SET_TITLE action)
- [x] Homebrew tap (alltuner/homebrew-tap) and cask formula
- [x] CI: automate build, sign, notarize, DMG, and release upload via GitHub Actions
- [x] CONTRIBUTING.md, CODE_OF_CONDUCT.md
- [x] Funding: Buy Me a Coffee, GitHub Sponsors (website + FUNDING.yml + CLI message)
- [x] Website: legal/privacy policy page (4 languages)
- [x] Workstream navigation shortcuts (Ctrl+1-9, Cmd+Shift+[/] cycling)
- [x] Security: disable JS in markdown WKWebView, restrict browser to http/https, fix AppleScript injection, fix PortAllocator hash stability, fix CI checkout version, fix CLI install path quoting
