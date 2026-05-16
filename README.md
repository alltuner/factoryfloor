<p align="center">
  <img src="https://raw.githubusercontent.com/barnolacesc/dockyard/main/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Dockyard">
</p>

<h1 align="center">Dockyard</h1>

<p align="center">
  <strong>AI-powered development workspace for macOS</strong><br>
  Git worktrees, coding agent sessions, and dev servers in a single native app.
</p>

<p align="center">
  <a href="https://francesc.barnola.net">Website</a> &middot;
  <a href="https://francesc.barnola.net/get/">Download</a> &middot;
  <a href="https://francesc.barnola.net/sponsor">Sponsor</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/barnolacesc/dockyard?color=5B2333" alt="License">
  <img src="https://img.shields.io/github/stars/barnolacesc/dockyard?color=5B2333" alt="Stars">
</p>

---

## Get Started

Install via Homebrew:

```bash
brew install --cask barnolacesc/tap/dockyard
```

Or [download the latest release](https://francesc.barnola.net/get/).

Then:

1. **Open Dockyard** and add a project by clicking the `+` button in the sidebar, then selecting a repository directory.
2. **Create a workstream** with `Cmd+N`. Dockyard sets up a git worktree and launches your selected coding CLI automatically.
3. **Start building.** Add terminals (`Cmd+T`), browsers (`Cmd+B`), editors (`Cmd+O`), or configure [run scripts](#script-configuration) to auto-detect your dev server.

---

## What is Dockyard?

Dockyard is a native macOS app built on [Ghostty](https://ghostty.org)'s GPU-rendered terminal. It manages multiple parallel development tasks, each in its own git worktree with a dedicated coding agent, terminal, and browser.

**One project, many workstreams, all at native speed.**

### Features

- **Git Worktrees** &mdash; Each workstream gets its own branch and worktree. Switch between tasks without stashing.
- **Selectable Coding CLI** &mdash; Run Claude Code or Codex in the Agent tab, with session resume support.
- **Tmux Persistence** &mdash; Agent sessions survive app restarts via tmux on a dedicated socket.
- **Setup & Run Scripts** &mdash; Configure setup, run, and teardown scripts per project via `.dockyard.json`. Environment tab with split-pane terminals, Start/Rerun (⌘⇧⏎).
- **Embedded Browser** &mdash; WKWebView tab with automatic port detection. The browser navigates to the port your run script opens.
- **Code Editor** &mdash; Built-in Monaco editor (same engine as VS Code) embedded via WKWebView. Syntax highlighting, IntelliSense, and file tree. One file per tab, shared undo history.
- **GitHub Integration** &mdash; Repo info, open PRs, and branch PR status via the `gh` CLI.
- **Dynamic Tabs** &mdash; Open as many terminals, browsers, and editors as you need. Close with Cmd+W or Ctrl+D.
- **Update Notifications** &mdash; Checks for new versions and shows a badge in the sidebar.
- **Keyboard-first** &mdash; Every action has a shortcut. Cmd+1-9 for tabs, Cmd+Return for agent, Cmd+T for terminal, Cmd+B for browser, Cmd+O for editor.

### Tmux Mode

When tmux mode is enabled (Settings > Terminal), Dockyard wraps Coding Agent sessions in tmux using a dedicated socket (`dockyard`). This keeps sessions alive across app restarts without interfering with your personal tmux setup.

The tmux config strips all UI chrome (status bar, prefix key, keybindings) since Dockyard manages the terminal directly. Sessions are still fully accessible from any external terminal:

```bash
# List active sessions
tmux -L dockyard list-sessions

# Attach to a session
tmux -L dockyard attach-session -t <session-name>
```

Note that because keybindings are removed, you will need to detach with `tmux -L dockyard detach-client` from another terminal, or use the standard `kill-session` command.

### Script Configuration

Add a `.dockyard.json` to your project root to automate your workstream lifecycle. All fields are optional.

```json
{
  "setup": "npm install",
  "run": "PORT=$DY_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | When it runs | Example use case |
|---|---|---|
| `setup` | Once, when a workstream is created | Install deps, copy .env, run build steps |
| `run` | On demand via the Environment tab | Start dev server, docker-compose up |
| `teardown` | When a workstream is archived | docker-compose down, clean temp files |

Scripts run in the workstream directory using your login shell. The `run` script is wrapped in the `dy-run` launcher for automatic port detection.

### Environment Variables

Every workstream terminal has access to:

| Variable | Description |
|---|---|
| `DY_PROJECT` | Project name |
| `DY_WORKSTREAM` | Workstream name |
| `DY_PROJECT_DIR` | Main repository path |
| `DY_WORKTREE_DIR` | Worktree path for this workstream |
| `DY_PORT` | Deterministic port (40001-49999) |

### Keyboard Shortcuts

#### Global

| Shortcut | Action |
|---|---|
| `Cmd+N` | New workstream or project |
| `Cmd+Shift+N` | New project |
| `Cmd+,` | Settings |
| `Cmd+/` | Help |
| `Cmd+Option+S` | Toggle sidebar |

#### Workstream

| Shortcut | Action |
|---|---|
| `Cmd+1` | Info |
| `Cmd+2` | Coding Agent |
| `Cmd+3-9` | Switch tab |
| `Cmd+Shift+[` / `]` | Cycle tabs |
| `Cmd+Return` | Focus Coding Agent |
| `Cmd+Shift+Return` | Split Agent pane |
| `Cmd+I` | Info panel |
| `Cmd+E` | Environment |
| `Cmd+T` | New Terminal |
| `Cmd+Shift+T` | Split Terminal pane |
| `Cmd+B` | New Browser |
| `Cmd+Shift+B` | Split Browser pane |
| `Cmd+O` | New Editor |
| `Cmd+S` | Save (Editor) |
| `Cmd+Shift+S` | Save As (Editor) |
| `Cmd+W` | Close tab |
| `Cmd+Shift+W` | Archive workstream |
| `Cmd+R` | Reload browser |
| `Cmd+Shift+R` | Hard reload browser (bypass cache) |
| `Cmd+L` | Address bar (browser) |

#### Navigation

| Shortcut | Action |
|---|---|
| `Cmd+[` / `]` | Cycle workstreams (current project) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Cycle workstreams (globally) |
| `Cmd+Up` / `Down` | Cycle projects |
| `Cmd+0` | Back to project |

#### External Apps

| Shortcut | Action |
|---|---|
| `Cmd+Option+B` | Open in external browser |
| `Cmd+Option+T` | Open in external terminal |

### Supported Languages

English, Catalan, German, Spanish, Swedish.

---

## Install

```bash
brew install --cask barnolacesc/tap/dockyard
```

Or [download the latest release](https://francesc.barnola.net/get/).

### Upgrade

```bash
brew upgrade --cask dockyard
```

### CLI

Homebrew automatically installs the `ff` command. If you installed via DMG, install the CLI from Settings > Environment.

---

## Development

Requires: Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), [Zig](https://ziglang.org) (`brew install zig`).

```bash
# First time: build the Ghostty terminal engine
cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast && cd ..

# Build
./scripts/dev.sh build

# Build and run
./scripts/dev.sh br

# Kill and relaunch
./scripts/dev.sh run

# Run with a specific directory
./scripts/dev.sh run ~/repos/myproject

# Run tests
./scripts/dev.sh test

# Clean
./scripts/dev.sh clean

# Release (sign, notarize, DMG)
./scripts/release.sh 0.1.0
```

See [CLAUDE.md](CLAUDE.md) for development workflow, architecture, and conventions.

### Website

The website lives in `website/` and is built with [Hugo](https://gohugo.io) + [Tailwind CSS](https://tailwindcss.com).

```bash
cd website && bun install && bun run dev
```

### Localization

All strings are localized. To add a language:

1. Copy `Localization/en.lproj` to `Localization/xx.lproj`
2. Translate all values in `Localizable.strings`
3. Add the path to `project.yml` and run `xcodegen generate`

## Credits

Dockyard is built on the shoulders of these projects:

- **[Ghostty](https://ghostty.org)** — GPU-accelerated terminal engine (Metal-rendered via libghostty)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — AI coding agent by Anthropic
- **[Codex CLI](https://developers.openai.com/codex)** — AI coding agent by OpenAI
- **[tmux](https://github.com/tmux/tmux/wiki)** — Terminal multiplexer for session persistence
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — Xcode project generation from `project.yml`
- **[cmark-gfm](https://github.com/github/cmark-gfm)** — GitHub Flavored Markdown rendering (via [swift-cmark](https://github.com/swiftlang/swift-cmark))
- **[Hugo](https://gohugo.io)** + **[Tailwind CSS](https://tailwindcss.com)** — Website
- **[Umami](https://umami.is)** — Privacy-friendly website analytics

## Support the project

Dockyard is an open source project built by [David Poblador i Garcia](https://davidpoblador.com/) through [David Poblador i Garcia](https://www.barnolacesc.com/).

If this project helped you ship faster, automate your workflow, or experiment with coding agents, consider supporting its development.

❤️ **Sponsor development**
https://github.com/sponsors/barnolacesc

☕ **One-time support**
https://buymeacoffee.com/barnolacesc

Your support helps fund the continued development of Dockyard and other open source developer tools such as [VibeTuner](https://github.com/barnolacesc/vibetuner).

## License

[MIT](LICENSE)

---

<p align="center">
  Built by <a href="https://davidpoblador.com">David Poblador i Garcia</a> with the support of <a href="https://barnolacesc.com">David Poblador i Garcia</a>.<br>
  Made with ❤️ in Poblenou, Barcelona.
</p>
