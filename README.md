<p align="center">
  <img src="https://raw.githubusercontent.com/alltuner/factoryfloor/main/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Factory Floor">
</p>

<h1 align="center">Factory Floor</h1>

<p align="center">
  <strong>AI-powered development workspace for macOS</strong><br>
  Git worktrees, Claude Code sessions, and dev servers in a single native app.
</p>

<p align="center">
  <a href="https://factory-floor.com">Website</a> &middot;
  <a href="https://factory-floor.com/get/">Download</a> &middot;
  <a href="https://factory-floor.com/sponsor">Sponsor</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/alltuner/factoryfloor?color=5B2333" alt="License">
  <img src="https://img.shields.io/github/stars/alltuner/factoryfloor?color=5B2333" alt="Stars">
</p>

---

## Get Started

Install via Homebrew:

```bash
brew install --cask alltuner/tap/factoryfloor
```

Or [download the latest release](https://factory-floor.com/get/).

Then:

1. **Open Factory Floor** and add a project by clicking the `+` button in the sidebar, then selecting a repository directory.
2. **Create a workstream** with `Cmd+N`. Factory Floor sets up a git worktree and launches a Claude Code agent automatically.
3. **Start building.** Add terminals (`Cmd+T`), browsers (`Cmd+B`), or configure [run scripts](#script-configuration) to auto-detect your dev server.

---

## What is Factory Floor?

Factory Floor is a native macOS app built on [Ghostty](https://ghostty.org)'s GPU-rendered terminal. It manages multiple parallel development tasks, each in its own git worktree with a dedicated Claude Code agent, terminal, and browser.

**One project, many workstreams, all at native speed.**

### Features

- **Git Worktrees** &mdash; Each workstream gets its own branch and worktree. Switch between tasks without stashing.
- **Claude Code** &mdash; Integrated AI agent with session persistence. Resume conversations across app restarts.
- **Tmux Persistence** &mdash; Agent sessions survive app restarts via tmux on a dedicated socket.
- **Setup & Run Scripts** &mdash; Configure setup, run, and teardown scripts per project via `.factoryfloor.json`. Environment tab with split-pane terminals, Rebuild (⌃⇧R) and Start/Rerun (⌃⇧S).
- **Embedded Browser** &mdash; WKWebView tab with automatic port detection. The browser navigates to the port your run script opens.
- **GitHub Integration** &mdash; Repo info, open PRs, and branch PR status via the `gh` CLI.
- **Dynamic Tabs** &mdash; Open as many terminals and browsers as you need. Close with Cmd+W or Ctrl+D.
- **Update Notifications** &mdash; Checks for new versions and shows a badge in the sidebar.
- **Keyboard-first** &mdash; Every action has a shortcut. Cmd+Return for agent, Cmd+I for info, Cmd+E for environment, Cmd+T for terminal, Cmd+B for browser.

### Script Configuration

Add a `.factoryfloor.json` to your project root:

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

### Environment Variables

Every workstream terminal has access to:

| Variable | Description |
|---|---|
| `FF_PROJECT` | Project name |
| `FF_WORKSTREAM` | Workstream name |
| `FF_PROJECT_DIR` | Main repository path |
| `FF_WORKTREE_DIR` | Worktree path for this workstream |
| `FF_PORT` | Deterministic port (40001-49999) |

### Keyboard Shortcuts

#### Global

| Shortcut | Action |
|---|---|
| `Cmd+N` | New workstream or project |
| `Cmd+Shift+N` | New project |
| `Cmd+,` | Settings |
| `Cmd+/` | Help |

#### Workstream

| Shortcut | Action |
|---|---|
| `Cmd+Return` | Focus Coding Agent |
| `Cmd+I` | Info panel |
| `Cmd+E` | Environment |
| `Cmd+T` | New Terminal |
| `Cmd+B` | New Browser |
| `Cmd+W` | Close tab |
| `Cmd+L` | Address bar (browser) |
| `Cmd+0` | Back to project |
| `Cmd+1-9` | Switch tab |
| `Ctrl+1-9` | Switch workstream |
| `Cmd+Shift+[` / `]` | Cycle tabs |
| `Cmd+Shift+O` | External browser |
| `Cmd+Shift+E` | External terminal |
| `Ctrl+Shift+R` | Rebuild setup |
| `Ctrl+Shift+S` | Start/Rerun |

### Supported Languages

English, Catalan, Spanish, Swedish.

---

## Install

```bash
brew install --cask alltuner/tap/factoryfloor
```

Or [download the latest release](https://factory-floor.com/get/).

### Upgrade

```bash
brew upgrade --cask factoryfloor
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

Factory Floor is built on the shoulders of these projects:

- **[Ghostty](https://ghostty.org)** — GPU-accelerated terminal engine (Metal-rendered via libghostty)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — AI coding agent by Anthropic
- **[tmux](https://github.com/tmux/tmux/wiki)** — Terminal multiplexer for session persistence
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — Xcode project generation from `project.yml`
- **[cmark-gfm](https://github.com/github/cmark-gfm)** — GitHub Flavored Markdown rendering (via [swift-cmark](https://github.com/swiftlang/swift-cmark))
- **[Hugo](https://gohugo.io)** + **[Tailwind CSS](https://tailwindcss.com)** — Website
- **[Umami](https://umami.is)** — Privacy-friendly website analytics

## Support the project

Factory Floor is an open source project built by [David Poblador i Garcia](https://davidpoblador.com/) through [All Tuner Labs](https://www.alltuner.com/).

If this project helped you ship faster, automate your workflow, or experiment with coding agents, consider supporting its development.

❤️ **Sponsor development**
https://github.com/sponsors/alltuner

☕ **One-time support**
https://buymeacoffee.com/alltuner

Your support helps fund the continued development of Factory Floor and other open source developer tools such as [VibeTuner](https://github.com/alltuner/vibetuner).

## License

[MIT](LICENSE)

---

<p align="center">
  Built by <a href="https://davidpoblador.com">David Poblador i Garcia</a> with the support of <a href="https://alltuner.com">All Tuner Labs</a>.<br>
  Made with ❤️ in Poblenou, Barcelona.
</p>
