---
title: Docs
translationKey: docs
hideInstall: true
layout: docs
---

## Getting Started

The year is 2026. We build on tmux (2007), git worktrees (2015), terminals (1978, the VT100 era, when even [David](https://davidpoblador.com) was only a future project), and GPU rendering (thanks [Mitchell](https://mitchellh.com) for [Ghostty](https://ghostty.org)). Old tools, new tricks.

You need two things: a Mac and a vague sense that your current workflow could be better.

```
brew install --cask factory-floor
```

<a href="https://github.com/alltuner/factoryfloor/releases/latest/download/FactoryFloor.dmg" class="docs-download"><svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download DMG</a>

Factory Floor works best when these are installed (it'll tell you if they're missing):

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — the whole point, really
- **git** — you probably have this
- **[gh](https://cli.github.com/)** — GitHub CLI, for PR status and quick actions
- **[tmux](https://github.com/tmux/tmux)** — optional, enables session persistence

#### Your first 30 seconds

1. Open Factory Floor
2. Drop a git repository onto the sidebar (or click **+** to pick one)
3. Hit **⌘N** to create a workstream
4. That's it. You're coding with AI now.

No config files required. Factory Floor detects your git setup, installed tools, and GitHub connections automatically.

---

## Core Concepts

The three things you'll interact with every day.

### Projects

A project is a git repository. Drop a directory on the sidebar or click the **+** button. Factory Floor checks if it's a git repo (and offers to initialize one if it's not).

The project overview shows repository info, GitHub details (stars, forks, open issues), up to 5 recent PRs, and auto-discovered markdown documentation from your repo.

Projects sort by **Recent** (last activity) by default. Toggle to **A-Z** if you're that kind of person.

Right-click a project in the sidebar for quick access: **Reveal in Finder**, **Open in External Terminal**, **Open on GitHub**, or **Remove** (files stay on disk, we're not monsters).

### Workstreams

A workstream is where the work happens. Each one gets its own git worktree, branch, terminal, coding agent, and browser tab. They're completely isolated from each other.

**⌘N** creates a new workstream. Behind the scenes:

1. Fetches the latest default branch from origin
2. Creates a git worktree with a fresh branch (prefixed with your branch prefix, default: `ff`)
3. Symlinks `.env` and `.env.local` from the main repo (if enabled)
4. Runs the setup script (if configured)
5. Launches the coding agent

The UI shows up instantly — worktree creation happens in the background.

#### Workstream tabs

- **Info** (⌘I) — branch name, PR status, project docs
- **Agent** (⌘Return) — your Claude Code session
- **Environment** (⌘E) — setup and run script controls
- **Terminal** (⌘T) — additional terminal tabs, as many as you want
- **Browser** (⌘B) — embedded browser with auto-port detection

#### Branch auto-rename

With **Auto-rename branch** enabled in settings, the coding agent renames your branch to match the task on the first prompt. So `ff/coral-tidal-reef` becomes `ff/fix-login-timeout`.

#### Removing vs. purging

- **Remove** — kills terminals and agent, but the worktree stays on disk
- **Purge** — permanently deletes the worktree and branch (asks for confirmation if there are uncommitted changes)

When a PR is merged, Factory Floor shows a "Purge" badge so you know it's safe to clean up.

### The Coding Agent

The coding agent tab runs [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) in an embedded terminal. It sits right after the Info tab in every workstream.

#### Agent settings

- **Bypass permission prompts** — skips confirmation dialogs. Useful if you trust your agent (and live dangerously).
- **Tmux mode** — wraps agent sessions in tmux so they survive app restarts. Requires tmux.
- **Auto-rename branch** — lets the agent rename the branch to match the task.
- **Agent Teams** — experimental multi-agent coordination, courtesy of Claude Code. We trust Anthropic, don't we?

#### Quick actions

Quick actions run one-shot Claude tasks from the sidebar:

- **Commit** — stages and commits with an AI-generated message
- **Push** — pushes the current branch to origin
- **Create PR** — creates a pull request with AI-generated title and description
- **Abandon PR** — closes the PR

These run as background `claude -p` calls. Enable **Quick action debug mode** in settings if you want to know how the sausage is made. Trust us, [David](https://davidpoblador.com) spent more time than he can admit debugging weird behaviors in there.

---

## Your Workspace

Terminals, browsers, and shortcuts — the tools inside each workstream.

### Terminals

Terminals are GPU-rendered via [Ghostty](https://ghostty.org). They're fast.

- **⌘T** — new terminal tab
- **⌘W** — close tab (or Ctrl+D to exit the shell)
- **⌘1-9** — switch between tabs
- **⌘Shift+[** / **⌘Shift+]** — cycle through tabs

You can drag files and text onto the terminal. Because sometimes the mouse is fine, actually.

**⌘Shift+E** opens the workstream directory in your preferred external terminal app.

### The Browser

Every workstream can have browser tabs (⌘B). The browser is embedded — no window switching needed.

#### Port detection

When your run script starts a dev server, Factory Floor detects the listening port automatically and navigates the browser to it. No configuration needed. The `ff-run` launcher monitors the process tree for TCP listeners.

#### Navigation

- **⌘L** — focus the address bar
- **⌘Shift+O** — open current URL in your external browser
- **⌘Click** — opens links in your external browser

The browser shows a connection error page with a retry button if the server isn't ready yet. It'll auto-navigate once the port is detected.

### Keyboard Shortcuts

Factory Floor is keyboard-first. Here's everything.

#### Global

| Shortcut | Action |
|----------|--------|
| ⌘N | New workstream (or project, if none exist) |
| ⌘Shift+N | New project |
| ⌘, | Settings |
| ⌘/ | Help |

#### Workstream

| Shortcut | Action |
|----------|--------|
| ⌘Return | Focus Coding Agent |
| ⌘I | Info panel |
| ⌘E | Environment |
| ⌘T | New Terminal |
| ⌘B | New Browser |
| ⌘W | Close tab |
| ⌘L | Address bar (browser) |
| ⌘0 | Back to project |
| ⌘1-9 | Switch tab |
| ⌘Shift+[ | Previous tab |
| ⌘Shift+] | Next tab |
| Ctrl+Shift+R | Rebuild setup |
| Ctrl+Shift+S | Start/restart run |

#### Navigation

| Shortcut | Action |
|----------|--------|
| Ctrl+1-9 | Switch workstream (from any view) |
| ⌘Shift+O | Open in external browser |
| ⌘Shift+E | Open in external terminal |

---

## Configuration

How to automate the boring parts.

### Scripts & Lifecycle

Drop a `.factoryfloor.json` in your project root to automate the workstream lifecycle.

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | When it runs |
|------|-------------|
| `setup` | Once, when a workstream is created. Install dependencies, run migrations, whatever. |
| `run` | On demand via the Environment tab (⌘E). Wrapped in `ff-run` for port detection. |
| `teardown` | When a workstream is archived or purged. Stop containers, clean up. |

All fields are optional. Scripts run in the workstream directory using your login shell. Yes, even [fish](https://github.com/alltuner/factoryfloor/pull/324). Don't ask how long that took.

Factory Floor also reads `conductor.json` and `.superset/config.json` if `.factoryfloor.json` doesn't exist. Because compatibility is polite. (Time for a [standard](https://xkcd.com/927/)?)

#### The Environment tab

Split-pane layout: **Setup** on the left, **Run** on the right.

- **Ctrl+Shift+R** — rebuild (reruns setup)
- **Ctrl+Shift+S** — start/restart the run script

### Environment Variables

Every terminal, setup script, and run command in a workstream has these variables:

| Variable | What it is | Example |
|----------|-----------|---------|
| `FF_PROJECT` | Project name | `my-app` |
| `FF_WORKSTREAM` | Workstream name | `coral-tidal-reef` |
| `FF_PROJECT_DIR` | Main repository path | `/Users/you/my-app` |
| `FF_WORKTREE_DIR` | Worktree path | `~/.factoryfloor/worktrees/my-app/coral-tidal-reef` |
| `FF_PORT` | Deterministic port (40001-49999) | `42847` |

#### About FF_PORT

Each workstream gets a deterministic port based on a hash of the worktree path. Same workstream, same port, every time. No port conflicts between workstreams. Use it in your run script: `PORT=$FF_PORT npm run dev`. If your thing is running thousands of workstreams simultaneously, you might get a collision 🎲 but hopefully you run out of memory first.

#### .env symlink

When enabled (Settings > General), Factory Floor symlinks `.env` and `.env.local` from your main repo into each worktree. So your secrets follow you without copy-pasting. Speaking of secrets, have we told you about [Vaultuner](https://vaultuner.alltuner.com)?

### Settings

Open with **⌘,** or click the gear icon.

#### General

- **Base directory** — default location for new projects
- **Branch prefix** — prefix for workstream branches (default: `ff`)
- **Symlink .env files** — auto-symlink `.env` and `.env.local` to worktrees
- **Theme** — System, Light, or Dark
- **Language** — System default, English, Catalan, Spanish, or Swedish
- **Confirm before quitting** — asks before closing with active workstreams
- **Launch at login** — starts Factory Floor on boot

#### Coding Agent

- **Bypass permission prompts** — disables confirmation for agent actions
- **Agent Teams** — experimental multi-agent mode
- **Auto-rename branch** — agent renames branch on first prompt
- **Tmux mode** — session persistence via tmux

#### Apps

- **External Terminal** — which terminal app to open with ⌘Shift+E
- **External Browser** — which browser for ⌘Shift+O and ⌘Click

#### Advanced

- **Usage analytics** — privacy-friendly telemetry (app version, OS, locale only)
- **Crash reports** — Sentry-based crash reporting
- **Detailed logging** — logs script output for debugging
- **Quick action debug mode** — shows raw output from quick actions
- **Bleeding edge updates** — opt into pre-release builds
- **Clear project list** — nuclear option, removes all projects from sidebar

---

## Integrations

Connecting Factory Floor to everything else.

### CLI

Install the `ff` command from Settings > Environment > Install CLI. Then:

```
ff /path/to/your/project
```

Opens the directory in Factory Floor. That's all it does, and that's all it needs to do.

### GitHub

Requires the [gh CLI](https://cli.github.com/) with authentication (`gh auth login`).

- **Project view** — repo info, description, stars, forks, open issues, recent PRs
- **Workstream sidebar** — PR number, title, and status (open/merged/closed) per branch
- **Merged detection** — shows "Purge" badge when a branch's PR is merged

#### Quick actions

From the sidebar, run one-click operations: **Create PR** (AI-generated title and description), **Push** (to origin with `-u`), or **Abandon PR** (closes with a comment). Because if you're tired of typing "now commit, push, and open a PR" into Claude for the hundredth time, you're not alone.

### Updates

Factory Floor shows a badge in the sidebar when a newer version is available. You can also check manually from **Factory Floor > Check for Updates...**

**Homebrew users:**

```
brew upgrade factory-floor
```

**DMG users:** updates are handled automatically via [Sparkle](https://sparkle-project.org). Check manually from the menu: **Factory Floor > Check for Updates...**

Enable **Bleeding edge updates** in Settings > Advanced for pre-release builds. For those who like to live on the edge and file bug reports.

---

## Enterprise Features 😉

### Code Editor

Nope. No syntax highlighting, no autocomplete, no minimap. Our nonexistent VCs have not been pushing any corporate agenda. We intend to have you using the tools you already love: [Zed](https://zed.dev), [VS Code](https://code.visualstudio.com), whatever. Factory Floor gives you a coding agent, a browser, and a worktree. Besides, who's writing code anymore?

### Merge Viewer

Also nope. Your git client already does this better than we ever would. We just make sure each workstream has a clean branch ready for review. You are keeping your PRs small and avoiding merge conflicts, right? ...Right?

---

## Troubleshooting

#### "Tools not found"

Factory Floor detects tools from your login shell. If `claude`, `gh`, `git`, or `tmux` aren't showing up:

- Make sure they're in your shell's PATH
- Fish 4.0 and Nix users: the app handles these environments, but if something's off, check Settings > Environment

#### Tmux sessions not persisting

- Verify tmux is installed and detected (Settings > Environment)
- Factory Floor uses its own tmux socket (`-L factoryfloor`), so your personal tmux config won't interfere

#### Port not detected

- Make sure your run script uses `$FF_PORT` (or the port gets detected from the process tree)
- The `ff-run` launcher wraps the run script — it monitors child processes for listening TCP ports
- Check Settings > Advanced > Detailed logging for debug output

#### Something else broken?

- [Report a bug](https://github.com/alltuner/factoryfloor/issues/new?template=bug_report.yml) — tell us what went wrong
- [Submit a fix prompt](https://github.com/alltuner/factoryfloor/issues/new?template=fix_prompt.yml) — write the prompt, we'll let the agent take a crack at it
- [Something else](https://github.com/alltuner/factoryfloor/issues/new) — ideas, questions, existential doubts
