# Factory Floor - Project Instructions

## Development Workflow

### Build, Test, Run
```bash
./scripts/dev.sh build              # debug build (xcodegen + xcodebuild)
./scripts/dev.sh br                 # build and run
./scripts/dev.sh run [dir]          # kill and relaunch (optionally with a directory)
./scripts/dev.sh test               # run XCTest suite
./scripts/dev.sh release            # release build matching CI (hardened runtime)
./scripts/dev.sh release --run      # release build and run
./scripts/dev.sh clean              # clean build artifacts
./scripts/release.sh [version]      # release build: sign, notarize, create DMG
```

### After code changes
1. If you added/removed files or changed `project.yml`: run `xcodegen generate` first
2. Build and run: `./scripts/dev.sh br`
3. If tmux mode was on: `tmux -L factoryfloor kill-server`
4. If you changed the tmux config: `rm -f ~/Library/Caches/factoryfloor/tmux.conf`

### When to regenerate the Xcode project
Run `xcodegen generate` when:
- Adding or removing Swift source files
- Adding or removing localization files (lproj)
- Changing `project.yml` (build settings, dependencies, targets)

Do NOT edit `FactoryFloor.xcodeproj` directly. It is generated from `project.yml`.

### Release build
```bash
./scripts/release.sh [version]   # builds, signs, notarizes, creates DMG
```

## Git Workflow

### Conventional Commits
All commits MUST use [Conventional Commits](https://www.conventionalcommits.org/) format. This is required for release-please to generate changelogs and version bumps.

Format: `type(scope): description`

Types:
- `feat`: new feature (triggers minor version bump)
- `fix`: bug fix (triggers patch version bump)
- `refactor`: code change that neither fixes a bug nor adds a feature
- `perf`: performance improvement
- `docs`: documentation only
- `ci`: CI/CD changes
- `chore`: maintenance, dependencies, config

Examples:
```
feat: add multiple terminal tabs with Cmd+T
fix: resolve terminal freeze when opening second surface
refactor: extract env var injection to WorkstreamEnvironment
docs: update README with keyboard shortcuts
ci: add GitHub Pages deploy workflow
feat(website): add language switcher to footer
fix(browser): auto-focus address bar on new tab
```

Breaking changes: add `!` after the type or include `BREAKING CHANGE:` in the footer.

### Branching
- Work on feature branches, not directly on `main`
- Branch names: `feat/description`, `fix/description`, `refactor/description`
- Open PRs against `main`
- release-please manages version bumps and changelogs via PR

## Architecture

- **SwiftUI sidebar** + **AppKit terminal views** (Metal GPU-rendered via libghostty)
- **XcodeGen** for project generation (`project.yml` -> xcodeproj)
- **Ghostty** as git submodule (pinned to stable tags), xcframework built with `zig build`
- **Bridging header** at `Resources/FactoryFloor-Bridging-Header.h`
- **Single-window** app via `Window` (not `WindowGroup`)
- **`factoryfloor://`** URL scheme for single-instance behavior
- **AppConstants** (`appID`, `appName`, `configDirectory`, `dataDirectory`)

### Key directories
- `Sources/Models/` - Data models, git operations, tmux, name generator, app constants
- `Sources/Terminal/` - Ghostty integration (TerminalApp singleton, TerminalView NSView)
- `Sources/Views/` - SwiftUI views (sidebar, settings, project overview, workspace, browser)
- `Localization/` - lproj directories with Localizable.strings
- `Resources/` - Info.plist, entitlements, bridging header, Assets.xcassets, CLI script
- `ghostty/` - Git submodule (do not modify, pinned to stable release tag)
- `website/` - Hugo + Tailwind CSS site for factory-floor.com
- `scripts/` - Release and build automation
- `docs/` - Distribution guide and reference docs

### Data flow
- **Projects/workstreams** stored as JSON files in `~/.config/factoryfloor/`, accessed via `ProjectStore`
- **Settings** use `@AppStorage` (UserDefaults), keyed as `factoryfloor.*`
- **Terminal surfaces** cached in `TerminalSurfaceCache` (keyed by UUID)
- **Git repo info** cached in `AppEnvironment`, refreshed async every 15s
- **Tool detection** runs at startup in `AppEnvironment.refresh()`
- **Sidebar state** (selection, expanded sections) persisted as JSON via `SidebarSelection` / `SidebarState`

### Workstream lifecycle
1. Creating a workstream: generates name, runs `git worktree add`, symlinks .env (if enabled)
2. Workspace view: Agent tab always present, terminals/browsers added on demand
3. Tmux mode: wraps Coding Agent only in `tmux new-session -A` on socket `-L factoryfloor`
4. Terminal tabs: close on shell exit (Ctrl+D). Agent respawns.
5. Archiving: runs teardown script, then `git worktree remove` + `tmux kill-session`

### Script configuration
Scripts are loaded from `.factoryfloor.json` in the project directory:
```json
{ "setup": "cmd", "run": "cmd", "teardown": "cmd" }
```

### Port detection
Run scripts are wrapped in the `ff-run` launcher binary (bundled at `Contents/Helpers/ff-run`).
The launcher monitors the child process tree for listening TCP ports using `libproc` and writes
state to `~/Library/Caches/factoryfloor/run-state/<workstream-id>.json`. The app watches these files
via FSEvents and retargets the embedded browser when a port is detected.

### Paths
- Config: `~/.config/factoryfloor/` (respects `XDG_CONFIG_HOME`)
- Cache: `~/Library/Caches/factoryfloor/` (run-state, tmux.conf)
- Data/worktrees: `~/.factoryfloor/`
- URL scheme: `factoryfloor://`
- Bundle ID: `com.alltuner.factoryfloor`

## Localization

All user-facing strings MUST use localization. Never hardcode strings directly in SwiftUI views or code.

### Rules
- **SwiftUI Text/Button/Label**: Use string literals directly (e.g., `Text("Cancel")`). SwiftUI automatically treats these as `LocalizedStringKey`.
- **AppKit APIs** (NSOpenPanel, NSAlert, etc.): Use `NSLocalizedString("string", comment: "")`.
- **String interpolation with Images**: Split into `Text` concatenation. E.g., `(Text("Press ") + Text(Image(systemName: "command")) + Text(" N"))`.
- **Every new user-facing string** must be added to all 4 locale files.
- Current locales: English (en), Catalan (ca), Spanish (es), Swedish (sv).

## Keyboard Shortcuts
When adding, removing, or changing keyboard shortcuts:
1. Update `FF2App.swift` (menu commands)
2. Update `TerminalContainerView.swift` (workspace tab handling)
3. Update `HelpView.swift` (shortcut reference)
4. Update `README.md` (shortcut table)
5. Update website shortcuts section

Current shortcuts:
- **Cmd+Return**: Focus Coding Agent
- **Cmd+I**: Info panel
- **Cmd+E**: Environment
- **Cmd+T**: New Terminal
- **Cmd+B**: New Browser
- **Cmd+W**: Close tab
- **Cmd+L**: Address bar (browser)
- **Cmd+0**: Back to project
- **Cmd+1-9**: Switch tab (custom tabs only; Info=Cmd+I, Agent=Cmd+Return)
- **Ctrl+1-9**: Switch workstream (works from any view in a project)
- **Cmd+Shift+[/]**: Cycle tabs
- **Cmd+Shift+O**: External browser
- **Cmd+Shift+E**: External terminal
- **Cmd+/**: Help

## Naming
- The app is "Factory Floor". Internal ID is `factoryfloor` (no hyphen).
- Domain is `factory-floor.com` (hyphen only in the domain name).
- Use `AppConstants.appID` and `AppConstants.appName`, not hardcoded strings.
- Use "directory" not "folder" in all user-facing text.
- Use "Coding Agent" for the claude terminal tab.
- Use "workstream" for the sub-units of a project.

## Task Tracking
- **TODO.md**: Track bugs, features, and future work. Add items when you discover issues or defer work.
