# Factory Floor - Architecture, Code & Security Review

**Date:** 2026-03-18 (initial), 2026-04-03 (updated)
**Scope:** Full codebase review covering architecture, code quality, and security
**Codebase:** ~10,630 lines of Swift across 45 source files, 17 test files
**Version:** 0.1.23 (initial), 0.1.65 (updated)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Source File Inventory](#2-source-file-inventory)
3. [Build System & Targets](#3-build-system--targets)
4. [Data Flow & Persistence](#4-data-flow--persistence)
5. [State Management](#5-state-management)
6. [Concurrency Model](#6-concurrency-model)
7. [Security Review](#7-security-review)
8. [Code Quality Review](#8-code-quality-review)
9. [Testing Coverage](#9-testing-coverage)
10. [Findings & Recommendations](#10-findings--recommendations)

---

## 1. Architecture Overview

Factory Floor is a native macOS application that provides an integrated development environment for managing multiple parallel AI-assisted development workstreams. It combines SwiftUI (modern UI), AppKit (terminal views), and the Ghostty terminal engine (Metal GPU-rendered).

**Key architectural decisions:**
- **Swift 6.0** with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- **macOS 14.0+** deployment target
- **XcodeGen** for project generation (`project.yml` -> xcodeproj)
- **Ghostty** as git submodule (pinned to stable release tag), xcframework built with `zig build`
- **Single-window** app via `Window` (not `WindowGroup`)
- **No sandbox** - intentional, needs full filesystem access for git worktrees and terminals
- **Bundle ID:** `com.alltuner.factoryfloor` (release) / `com.alltuner.factoryfloor.debug` (debug)

### View Hierarchy

```
Window (Single window, non-WindowGroup)
└── ContentView
    ├── ProjectSidebar (NavigationSplitView sidebar)
    │   ├── Project headers (collapsible, drag-drop directory support)
    │   └── Workstream list (context menus, renaming, archiving)
    └── Detail area
        ├── SettingsView
        ├── HelpView
        ├── ProjectOverviewView
        │   ├── Project metadata & worktree list
        │   └── Doc tabs (markdown rendering)
        └── TerminalContainerView
            ├── TabBar (Info, Agent, Environment, Terminal*, Browser*)
            ├── InfoView (WKWebView markdown reader)
            ├── TerminalView (Ghostty surface, NSView subclass)
            ├── EnvironmentTabView (split-pane setup/run scripts)
            └── BrowserView (WKWebView with navigation bar)
```

### Data Flow

```
ProjectStore (JSON) ──> ContentView (@StateObject) ──> Sidebar / Detail views
                                                            │
AppEnvironment ──> Tool detection, git info cache ──────────┘
                   (async refresh every 5-60s)

TerminalSurfaceCache ──> TerminalView (Ghostty surface lifecycle)

PortDetector (FSEvents) ──> BrowserView (auto-retarget on port change)
    ↑
ff-run (helper binary) ──> run-state JSON files
    ↑
Run scripts (.factoryfloor.json)
```

---

## 2. Source File Inventory

### Application Entry Point
| File | Lines | Purpose |
|------|-------|---------|
| `Sources/FF2App.swift` | 224 | @main app struct, Ghostty init, window config, keyboard shortcuts, URL scheme, Sentry setup, quit confirmation |

### Models (Sources/Models/) - ~2,290 lines total

| File | Lines | Purpose |
|------|-------|---------|
| `Project.swift` | 64 | Codable data structures for projects and workstreams |
| `WorkstreamEnvironment.swift` | 28 | Builds env var maps for terminal sessions (FF_PROJECT, FF_WORKSTREAM, etc.) |
| `GitOperations.swift` | 263 | Git repo detection, worktree create/remove, branch info, .env symlink injection |
| `GitHubOperations.swift` | 100 | Integrates with `gh` CLI for repo info, PR lists |
| `RunLauncher.swift` | 29 | Locates ff-run helper, builds wrapped run-script commands |
| `RunState.swift` | 147 | RunStateSnapshot encoding/decoding, port selection logic (PortSelectionTracker) |
| `PortDetector.swift` | 98 | FSEvents watcher for run state files, publishes selectedPort |
| `PortAllocator.swift` | 20 | Deterministic port allocation (40001-49999) using DJB2 hash |
| `TmuxSession.swift` | 120 | Session naming, minimal config generation, command wrapping |
| `TerminalApp.swift` | 192 | Ghostty C API integration: app lifecycle, surface callbacks, clipboard |
| `FilePersistence.swift` | 26 | Atomic file writes via temp files with rename (crash-safe) |
| `ScriptConfig.swift` | 65 | Loads .factoryfloor.json (setup/run/teardown scripts) |
| `SidebarSelection.swift` | — | Navigation state persistence |
| `CommandBuilder.swift` | 49 | Shell command escaping (single-quote wrapping) |
| `CommandLineTools.swift` | 41 | Tool discovery across homebrew, system, and user paths |
| `Environment.swift` | 254 | @MainActor AppEnvironment: tool detection, git info caching, GitHub integration |
| `UpdateChecker.swift` | 48 | Checks factory-floor.com/versions.json for updates |
| `AppConstants.swift` | 54 | Centralized config: directories, app ID, URL scheme |
| `PathUtilities.swift` | 42 | Path abbreviation, deterministic UUID derivation |
| `NameGenerator.swift` | 62 | Generates unique workstream names (operation-adjective-component, 126k combos) |
| `CacheMigration.swift` | 44 | Migrates cache/config paths between app versions |
| `DetailedLog.swift` | 14 | Structured log entry model |
| `LaunchAtLogin.swift` | 27 | Login item registration via SMAppService |
| `LaunchLogger.swift` | 97 | Logs app launch diagnostics to disk |
| `QuickActionRunner.swift` | 293 | Runs setup/run/teardown scripts with process lifecycle management |
| `SystemPrompts.swift` | 23 | Generates system prompt context for coding agents |
| `Telemetry.swift` | 98 | Anonymous usage telemetry (opt-in) |
| `Updater.swift` | 50 | Sparkle update integration |
| `WorkstreamArchiver.swift` | 38 | Coordinates teardown, worktree removal, tmux cleanup, cache eviction |

### Launcher (Sources/Launcher/) - Helper binary

| File | Lines | Purpose |
|------|-------|---------|
| `main.swift` | 277 | ff-run helper: spawns child processes, monitors process tree via `libproc`, detects listening TCP ports, signal forwarding, writes run state JSON |

### Terminal (Sources/Terminal/)

| File | Lines | Purpose |
|------|-------|---------|
| `TerminalView.swift` | 505 | NSView subclass hosting ghostty_surface_t, keyboard/mouse/resize handling, IME composition, C-string lifetime management |

### Views (Sources/Views/) - ~3,700 lines total

| File | Lines | Purpose |
|------|-------|---------|
| `ContentView.swift` | 420 | Main navigation container, ProjectList state, selection persistence |
| `ProjectSidebar.swift` | 839 | Collapsible project tree, drag-drop, sorting, context menus |
| `TerminalContainerView.swift` | 865 | Workspace tabs, session restoration, keyboard shortcuts, focus management |
| `ProjectOverviewView.swift` | 394 | Project info, worktree list, pruning, doc tabs |
| `WorkstreamInfoView.swift` | 330 | Workstream details, branch info, PR badge, script config |
| `EnvironmentTabView.swift` | 329 | Split-pane setup/run scripts, tmux session restoration |
| `BrowserView.swift` | 262 | WKWebView with navigation bar, port auto-retargeting, URL normalization |
| `SettingsView.swift` | 528 | App preferences, CLI installation, tool status, language selection |
| `OnboardingView.swift` | 217 | Prerequisites, getting started, key concepts |
| `HelpView.swift` | 170 | Keyboard shortcuts reference |
| `MarkdownView.swift` | 190 | WKWebView markdown rendering for docs |
| `PoblenouSkyline.swift` | 90 | Decorative skyline shape for onboarding |
| `UpdateBannerView.swift` | 106 | Update notification banner |

---

## 3. Build System & Targets

Three targets defined in `project.yml`:

### FactoryFloor (Main app)
- Type: application
- Dependencies: swift-cmark (v0.6.0+, markdown), Sentry (v9.7.0+, crash reporting)
- Links: libghostty, libz, libc++, Metal, MetalKit, CoreGraphics, AppKit, IOKit, Carbon
- Ghostty xcframework from: `ghostty/macos/GhosttyKit.xcframework/`
- Entitlements: `Resources/ff2.entitlements` (no sandbox)
- Post-build: copies ff-run to Contents/Helpers/, code-signs with hardened runtime
- Localization: en, ca, es, sv

### FFRun (Helper tool)
- Type: tool (command-line binary)
- Links: libproc only
- Sources: Launcher/main.swift + AppConstants.swift, FilePersistence.swift, RunState.swift

### FactoryFloorTests (XCTest)
- 11 test files covering ports, git, tmux, environment, UI state

---

## 4. Data Flow & Persistence

### Directory Structure
```
~/.config/factoryfloor/                    # Config (respects XDG_CONFIG_HOME)
├── projects.json                          # ProjectStore persistence
├── sidebar.json                           # Sidebar expanded/collapsed state
├── workspace-tabs.json                    # Per-workstream active tab (legacy)
├── tmux.conf                              # Auto-generated minimal tmux config
└── run-state/                             # Per-workstream JSON state files
    └── <workstream-uuid>.json             # PortSelectionResult, process status

~/.factoryfloor/worktrees/                 # Git worktrees
└── <project-name>/<workstream-name>/      # Actual working directories
```

### Persistence Mechanisms
| What | Where | Method |
|------|-------|--------|
| Projects/Workstreams | UserDefaults (`factoryfloor.projects`) | JSON (Codable), debounced saves |
| Sidebar state | `~/.config/factoryfloor/sidebar.json` | JSON, atomic writes |
| Workspace tabs | UserDefaults (`factoryfloor.workspaceTabs`) | JSON per workstream |
| App settings | UserDefaults (`factoryfloor.*`) | @AppStorage |
| Run state | `~/.config/factoryfloor/run-state/*.json` | Atomic writes, FSEvents watching |
| Git info cache | In-memory | Throttled async refresh (5s/60s) |
| Terminal surfaces | In-memory (TerminalSurfaceCache) | Keyed by UUID, evicted on archive |

---

## 5. State Management

### Pattern Summary
- **@StateObject**: `ProjectList` (source of truth in ContentView), `TerminalSurfaceCache`, `AppEnvironment`, `UpdateChecker`, `PortDetector`
- **@Published**: AppEnvironment properties (observable model)
- **@AppStorage**: 17+ user preferences in UserDefaults
- **NotificationCenter**: Cross-view communication (keyboard shortcuts, focus events)

### Potential Issues

- [ ] **MEDIUM - Surface cache orphaning**: If projects array is modified without notification, orphaned Ghostty surfaces remain cached in memory. Currently mitigated through notification-based cleanup in ContentView, but direct mutation could bypass this.

- [ ] **LOW - Sidebar index cache desync**: `cachedSortedIDs` and `cachedProjectIndex` in ProjectSidebar could diverge if projects are modified during a sort mode change. Low impact due to typically small project counts.

---

## 6. Concurrency Model

### Architecture
- `@MainActor` isolation on UI-facing classes: AppDelegate, AppEnvironment, TerminalApp, UpdateChecker
- `Task.detached` with `MainActor.run` for background work (git operations, tool detection)
- `DispatchQueue` for filesystem watching (PortDetector) and signal handling (Launcher)
- `DispatchSource` for non-blocking FSEvents monitoring
- `TaskGroup` for parallel git operations in AppEnvironment

### Thread Safety
- Sendable types enforced at compile time (verified by SwiftConcurrencySendableTests)
- Proper `weak self` in closures across 6+ files
- Explicit `deinit` cleanup in PortDetector, TerminalView

### Known Unsafe Code
- `TerminalApp`: `nonisolated(unsafe)` for ghostty_app_t pointer — initialized once in init, only read from main-thread callbacks. Safe but requires documentation.
- `TerminalView`: `nonisolated(unsafe)` static registry for C interop surface lookup
- `PortDetector`: `@unchecked Sendable` — uses dedicated dispatch queue for thread safety

---

## 7. Security Review

### 7.1 Entitlements & Sandboxing

**Finding: App is NOT sandboxed** (`com.apple.security.app-sandbox = false`)

- Intentional design decision — app needs unrestricted filesystem access for git worktrees, process spawning, terminal emulation
- Hardened runtime enabled for release builds
- Code signing with Developer ID certificate + Apple notarization

- [ ] **INFO** - Document the unsandboxed status and rationale in user-facing security documentation.

### 7.2 Command Execution & Shell Injection

**Overall: GOOD** — proper escaping and argument arrays throughout.

| Component | Method | Assessment |
|-----------|--------|------------|
| `CommandBuilder.shellQuote()` | Single-quote wrapping with `'\''` escaping | Correct |
| `GitOperations` | `Process()` with argument arrays | Safe (no shell interpretation) |
| `GitHubOperations` | `Process()` with argument arrays | Safe |
| `ScriptConfig` | `Process()` with argument arrays for teardown | Safe |
| `TmuxSession` | `shellEscape()` for session names and paths | Correct |
| `RunLauncher` | `CommandBuilder.shellQuote()` for launcher and script paths | Correct |
| `ff-run` (Launcher) | Validates `--workstream-id` UUID format | Correct |

**One area of note:**

- [ ] **LOW - AppleScript string interpolation**: `SettingsView.swift` (line ~277) constructs an AppleScript command for CLI installation with string interpolation. Manual escaping is applied correctly (replaces `'` with `'\''`), but it uses string construction rather than argument arrays. The scope is limited (only writes the bundled `ff` script to `/usr/local/bin`).

### 7.3 URL Scheme Handling

**File:** `FF2App.swift` (lines 98-105)

**No injection vulnerabilities.** The handler:
- Validates scheme matches `AppConstants.urlScheme`
- Checks path is not empty
- Validates path exists AND is a directory via FileManager
- No shell execution from URL parameters

### 7.4 File I/O & Symlink Attacks

**Symlink creation** (`GitOperations.symlinkEnvFiles`, lines 130-145):
- Checks source files are `.typeRegular` (not symlinks) — prevents symlink chain attacks
- Only allows whitelisted files (`.env`, `.env.local`)
- Prevents overwriting existing destination files
- Guarded by user toggle (`symlinkEnv` setting)

**Atomic writes** (`FilePersistence`, lines 12-25):
- Temp file + rename pattern (crash-safe)
- UUID-based temp filenames (TOCTOU resistant)
- Proper cleanup on failure

### 7.5 Network Security

| Endpoint | Protocol | Purpose |
|----------|----------|---------|
| `factory-floor.com/versions.json` | HTTPS | Update checking |
| Sentry (EU) | HTTPS | Crash reporting |
| `meta.factory-floor.com/meta.js` | HTTPS | Website analytics |

- No HTTP fallback anywhere
- Default URLSession certificate validation (no custom bypasses)
- No embedded servers or exposed network listeners

### 7.6 Browser/WebView Security

**BrowserView.swift:**
- JavaScript disabled (`allowsContentJavaScript = false`)
- Only `http` and `https` schemes allowed (blocks `file://`, `data://`, `javascript:`)
- Defaults to `http://` for bare URLs (reasonable for localhost dev servers)

**MarkdownView.swift:**
- Uses `CMARK_OPT_DEFAULT` (raw HTML not rendered)
- `escapeHTML()` fallback escapes `&`, `<`, `>` characters
- JavaScript disabled in WKWebView, navigation policy only allows http/https external links

- [x] ~~**LOW - CMARK_OPT_UNSAFE**~~: **Resolved (v0.1.65).** Now uses `CMARK_OPT_DEFAULT` with an `escapeHTML()` fallback. Raw HTML rendering is no longer enabled.

### 7.7 Credential & Secrets Handling

**Sentry DSN hardcoded** in `FF2App.swift` (lines 46-58):
```
https://45310bb703b438b38aee17e84e10d32e@o4511060356956160.ingest.de.sentry.io/...
```
- Acceptable practice — DSNs are intentionally public (write-only ingest keys)
- PII disabled: `sendDefaultPii = false`

**GitHub signing identity** in `scripts/release.sh`:
```
Developer ID Application: ALL TUNER LABS S.L. (J5TAY75Q3F)
```
- Public information (visible in signed binaries)

**No local credential storage** — GitHub auth delegated to `gh` CLI, no tokens stored in app.

### 7.8 Environment Variable Injection

`WorkstreamEnvironment.variables()` builds a controlled set:
- `FF_PROJECT`, `FF_WORKSTREAM`, `FF_PROJECT_DIR`, `FF_WORKTREE_DIR`, `FF_PORT`
- Optional: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
- No user input directly injected into env vars
- C environment array properly lifetime-managed in TerminalView

### 7.9 Git Operations Security

**Branch name sanitization** (`GitOperations`, lines 224-231):
- Removes leading hyphens (prevents git flag injection like `--upload-pack`)
- Replaces `/` with `--` (prevents path traversal)
- Replaces spaces with `-`
- Falls back to `"unnamed"` for empty results

**Worktree management:**
- Names sanitized before use in git commands
- Default branch detection tries `origin/main`, `origin/master`, `main`, `master` (no `@{...}` parsing)
- Worktree remove uses `--force` flag

### 7.10 Privilege Escalation

**CLI installation** (`SettingsView.swift`, lines 273-285):
- Uses NSAppleScript with `"with administrator privileges"` to write to `/usr/local/bin`
- User-initiated only (not automatic)
- Prompts system auth dialog
- Properly shell-escaped
- Scoped to only the `ff`/`ff-debug` CLI script with mode 755

### 7.11 Process Tree Monitoring

**ff-run launcher** (`Launcher/main.swift`):
- Monitors child process tree via `libproc` (proc_listchildpids, proc_pidinfo)
- Only examines listening TCP ports (TSI_S_LISTEN state check)
- Filters IPv4/IPv6 sockets
- Signal forwarding for SIGINT/SIGTERM via DispatchSourceSignal
- PID validation with `kill(pid, 0)` before trusting state

### 7.12 Clipboard Access

- Clipboard write: filters to `text/plain` MIME type only
- Clipboard read: handled via Ghostty callbacks with proper thread synchronization
- No arbitrary clipboard access

### 7.13 Logging & Telemetry

- `os.Logger` with proper privacy levels (`privacy: .public` only for non-sensitive data)
- No `print()` statements in production code
- Sentry: crash tracking + app hang tracking (5s threshold), PII disabled
- No sensitive data found in log statements

---

## 8. Code Quality Review

### 8.1 Error Handling — Excellent

- Consistent `do/catch` blocks in critical paths
- Process exit codes checked (`terminationStatus == 0`)
- Stderr captured and logged
- Graceful nil coalescing and optional handling throughout
- Atomic file writes with cleanup on failure

**Minor issue:**
- [ ] **LOW** - Some `try?` patterns silently suppress errors (e.g., `GitOperations.run` returns nil on error). Callers can't distinguish "tool not found" from "command failed". Currently handled correctly but could benefit from Result types for richer error context.

### 8.2 Memory Management — Excellent

- Proper `weak self` in closures across 6+ files
- Explicit `deinit` cleanup (PortDetector, TerminalView)
- `TerminalView.destroy()` explicitly frees Ghostty surface before deinit
- Caches bounded by project/workstream count (no unbounded growth)
- Terminal surface cache eviction on workstream archive

### 8.3 API Design — Clean

- Models are simple Codable structs (Project, Workstream, GitRepoInfo)
- Static enums for stateless operations (GitOperations, FilePersistence, CommandLineTools)
- ObservableObject for reactive state (AppEnvironment)
- Notifications for loose coupling between views
- No exposed internal state (caches are private)

### 8.4 Code Duplication — Low

Well-abstracted shared utilities:
- `CommandBuilder` centralizes shell command composition
- `FilePersistence` for atomic writes
- `CommandLineTools` for tool path resolution
- `WorkstreamArchiver` for shared cleanup logic

Some similar patterns in `GitOperations.run`, `GitHubOperations.run`, `TmuxSession` — but different enough that further abstraction would add complexity without benefit.

### 8.5 Force Unwraps & Crash Risks

**1 force unwrap found:**
```swift
// ContentView.swift line 371
selection = .workstream(direction > 0 ? sorted.first!.id : sorted.last!.id)
```

- [ ] **LOW** - `sorted.first!` / `sorted.last!` is safe because `guard !sorted.isEmpty` is checked on line 363, but the safety is non-obvious. Add a comment or use a safer alternative.

**Force casts:** None found.

### 8.6 Deprecated API Usage — None Found

- `@available(*, unavailable)` used correctly for unsupported initializers
- Modern SwiftUI patterns throughout (NavigationSplitView, etc.)

### 8.7 MD5 Usage

- [x] ~~**LOW** - MD5 used for CSS cache busting~~: **Resolved (v0.1.65).** MD5 usage removed from Swift source files.

### 8.8 Large Files

Several views are notably large and could benefit from extraction:
- [ ] **LOW - Refactoring opportunity**: `ProjectSidebar.swift` (839 lines) and `TerminalContainerView.swift` (865 lines) are the largest files. Consider extracting sub-components if they continue to grow.

### 8.9 Localization — Complete

All 4 locales (en, ca, es, sv) are complete with ~236 strings each. SwiftUI uses automatic LocalizedStringKey, AppKit uses NSLocalizedString correctly. No hardcoded English strings found outside comments.

---

## 9. Testing Coverage

### Test Files (17 total)

| Test File | Coverage Area |
|-----------|--------------|
| AppConstantsTests | Config directory resolution |
| AppDelegateTests | App delegate behavior |
| BrowserViewTests | TerminalSurfaceCache, WKWebView caching *(new)* |
| CommandBuilderTests | Shell escaping edge cases (20 tests) |
| CommandLineToolsTests | Tool discovery |
| EnvironmentTabViewTests | Environment pane behavior |
| GitOperationsTests | Worktree detection, branch detection, remote handling *(new)* |
| LaunchLoggerTests | Launch logging *(new)* |
| PortDetectionTests | Launcher wrapping, port selection stabilization, browser retargeting |
| ProjectTests | Project/workstream data models (13 tests) |
| ScriptConfigTests | Script configuration loading *(new)* |
| SwiftConcurrencySendableTests | Compile-time concurrency safety |
| TerminalSessionModeTests | Session mode switching |
| TerminalViewTests | Mouse coordinate conversion |
| TmuxSessionTests | Session naming, command wrapping |
| UpdateCheckerTests | Update checking logic *(new)* |
| WorkspaceTabStateTests | Tab state persistence |

### Coverage Gaps

- [x] ~~**MEDIUM - No tests for GitOperations**~~: **Resolved (v0.1.65).** `GitOperationsTests.swift` added with 10 tests covering worktree detection, branch detection, and remote handling. `.env` symlinking remains untested.
- [ ] **MEDIUM - No tests for Environment.swift**: Async caching, throttling, and refresh logic are still untested. Environment.swift contains complex async state with multiple caches (`repoInfoCache`, `pathValidityCache`, `branchNameCache`, etc.) and adaptive throttling (10s/60s).
- [ ] **LOW - No integration tests**: No end-to-end tests for project creation -> workstream -> terminal flow.
- [ ] **LOW - No tests for surface lifecycle**: Partially addressed via `BrowserViewTests.swift` (covers `TerminalSurfaceCache`), but TerminalView event handling and Ghostty surface lifecycle remain untested.

---

## 10. Findings & Recommendations

### Summary by Severity

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 2 | Surface cache orphaning, Environment.swift test gap |
| Low | 6 | Force unwrap, AppleScript string interpolation, error suppression, integration test gap, surface lifecycle test gap, large file refactoring |
| Info | 1 | Document unsandboxed status |
| Resolved | 3 | ~~CMARK_OPT_UNSAFE~~, ~~MD5 cache busting~~, ~~GitOperations test gap~~ |

### Actionable Items

#### Security
- [ ] Document the intentional unsandboxed status in user-facing documentation
- [x] ~~Consider `CMARK_OPT_SAFE` if markdown rendering scope expands beyond local READMEs~~: **Resolved.** Now uses `CMARK_OPT_DEFAULT`.
- [x] ~~Replace MD5 with SHA-256 for cache busting~~: **Resolved.** MD5 removed from Swift sources.
- [ ] Regularly audit third-party dependencies (Sentry, swift-cmark)

#### Code Quality
- [ ] Add comment to `ContentView.cycleWorkstream` (line 371) explaining why force unwrap is safe, or refactor to use optional chaining
- [ ] Consider adding `Result` types to `GitOperations.run` for richer error context
- [ ] Document `nonisolated(unsafe)` usage in `TerminalApp` with explanation of why it is safe
- [ ] Consider extracting sub-components from `ProjectSidebar.swift` and `TerminalContainerView.swift` if they continue to grow

#### Testing
- [x] ~~Add unit tests for `GitOperations`~~: **Resolved.** `GitOperationsTests.swift` covers worktree detection, branch detection, remote handling (10 tests). `.env` symlinking still untested.
- [ ] Add unit tests for `Environment.swift` (async caching, throttling, refresh)
- [ ] Add integration tests for workstream lifecycle (create -> terminal -> archive)
- [ ] Add tests for surface lifecycle management (partially covered by BrowserViewTests)

#### Architecture
- [ ] Address potential surface cache orphaning: add cleanup listener on project removal
- [ ] Consider rate limit handling for `gh` CLI calls (currently throttled to 30s intervals, low risk)
- [ ] Consider auto-update mechanism (Sparkle integration — already in TODO)

### Overall Assessment

**Score: 8.5/10** (initial), **9/10** (updated)

Factory Floor is a well-architected, production-ready macOS application with strong security practices. The codebase demonstrates:

- **Excellent** shell injection prevention via `CommandBuilder.shellQuote()` and Process argument arrays
- **Excellent** concurrency safety with Swift 6 strict concurrency and proper `@MainActor` isolation
- **Excellent** file I/O with atomic writes and symlink attack prevention
- **Excellent** memory management with proper weak references and explicit cleanup
- **Very good** error handling with logging throughout
- **Good** test coverage, improved since initial review (11 -> 17 test files), with room for improvement in Environment.swift and integration testing

No critical or high-severity issues were found. The application handles complex domains (concurrent terminal management, git operations, process monitoring) with care and delegates sensitive operations (GitHub auth, credential storage) to system tools.

### Changes Since Initial Review (v0.1.23 -> v0.1.65)

**Resolved findings:**
- `CMARK_OPT_UNSAFE` replaced with `CMARK_OPT_DEFAULT` plus `escapeHTML()` fallback
- MD5 cache busting removed from Swift sources
- GitOperations test coverage added (10 tests)

**New test files added:** GitOperationsTests, BrowserViewTests, LaunchLoggerTests, ScriptConfigTests, UpdateCheckerTests

**New source files added:** CacheMigration, DetailedLog, LaunchAtLogin, LaunchLogger, QuickActionRunner, SystemPrompts, Telemetry, Updater, PoblenouSkyline, UpdateBannerView

**Codebase growth:** ~7,250 -> ~10,630 lines across 37 -> 45 source files

**Security posture:** Maintained or improved. All new Process() calls use argument arrays. New files follow established patterns. No new critical or high-severity concerns identified.
