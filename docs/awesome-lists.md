# Awesome Lists Submission Guide

Where to list Factory Floor and how to get featured.

## Priority Targets

### Tier 1: High-impact, strong fit

#### 1. hesreallyhim/awesome-claude-code (31k stars)

The most relevant list. Factory Floor fits in the **"Alternative Clients"** section,
alongside crystal (desktop orchestrator), claude-tmux (tmux session manager with worktree
support), and Omnara (command center for AI agents).

- **Section:** Tooling > Alternative Clients > General
- **How to submit:** Open an issue using their [recommend-resource template](https://github.com/hesreallyhim/awesome-claude-code/issues/new?template=recommend-resource.yml). Do NOT open a PR; their automated system (Claude-managed) handles all PRs.
- **Competitors already listed:** crystal, claude-tmux, Omnara, Claudable, claude-esp
- **Ready-to-submit copy:**
  ```
  - [Factory Floor](https://github.com/alltuner/factoryfloor) by [David Poblador i Garcia](https://github.com/dpoblador) - Native macOS workspace for running multiple Claude Code agents in parallel. Each workstream gets its own git worktree, terminal (GPU-rendered via libghostty), and embedded browser with automatic dev server port detection.
  ```

#### 2. Uzaaft/awesome-libghostty (354 stars)

Curated list of projects built with libghostty. Has a dedicated **"AI Tools & Agent
Orchestration"** section. Direct competitors already listed: cmux, Commander, Mux, Supacode,
Aizen. Factory Floor is built on libghostty, so this is a natural home.

- **Section:** AI Tools & Agent Orchestration
- **How to submit:** Open a PR. See [CONTRIBUTING.md](https://github.com/Uzaaft/awesome-libghostty/blob/master/CONTRIBUTING.md).
- **Ready-to-submit copy:**
  ```
  * [Factory Floor](https://factory-floor.com) - A native macOS workspace for parallel development with git worktrees, Claude Code agents, and embedded dev servers with automatic port detection.
  ```

#### 3. jaywcjlove/awesome-mac (101k stars)

Massive reach. Factory Floor fits in **Developer Tools > Terminal Apps**.

- **Section:** Developer Tools > Terminal Apps
- **How to submit:** Open a PR. Read their [contributing guidelines](https://github.com/jaywcjlove/awesome-mac/blob/master/CONTRIBUTING.md). Uses icon badges for open source, freeware, etc.
- **Ready-to-submit copy:**
  ```
  * [Factory Floor](https://factory-floor.com) - Developer workspace that manages parallel tasks in git worktrees, each with its own terminal, AI agent, and embedded browser. [![Open Source Software][oss-icon]](https://github.com/alltuner/factoryfloor) ![Freeware][freeware-icon]
  ```
- **Notes:** Highly curated. Quality bar is high; the app needs to be polished with a good README and website screenshots.

#### 4. wyattgill9/Awesome-Ghostty (252+ stars)

Previously fearlessgeekmedia/Awesome-Ghostty (now archived, redirects to this fork).

- **Section:** Tools
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  * [Factory Floor](https://factory-floor.com) - Developer workspace built on Ghostty's GPU-rendered terminal for managing parallel git worktrees with integrated Claude Code agents and dev servers.
  ```
- **Notes:** Some overlap with awesome-libghostty, but different audience. This list is about the Ghostty ecosystem broadly; awesome-libghostty is about projects using the library.

### Tier 2: Good fit, worth pursuing

#### 5. kamranahmedse/developer-roadmap (352k stars)

The most popular developer resource on GitHub. Has a Claude Code roadmap with a
"Community Tools" page. Currently only lists Conductor.

- **Section:** Claude Code roadmap > Community Tools
- **How to submit:** Open a PR modifying `src/data/roadmaps/claude-code/content/community-tools@e12uqC2SEzaMfmBbz7VZf.md`.
- **Ready-to-submit copy:**
  ```
  - [@opensource@Factory Floor](https://github.com/alltuner/factoryfloor)
  - [@article@Factory Floor: Parallel Development with Git Worktrees and Claude Code](https://factory-floor.com)
  ```
- **Notes:** Extremely high visibility but strict review process. The community tools section is tiny, so there's room.

#### 6. openalternative.co (5.7k stars)

Open source alternatives directory with good SEO. superset.sh is listed here.

- **How to submit:** Submit at [openalternative.co/submit](https://openalternative.co/submit). Approved tools automatically appear in the GitHub repo.
- **Ready-to-submit copy:**
  - **Name:** Factory Floor
  - **URL:** https://factory-floor.com
  - **Repository:** https://github.com/alltuner/factoryfloor
  - **Description:** Open source macOS workspace for parallel development. Manages git worktrees, Claude Code agents, and dev servers in a single native app. Built on Ghostty's GPU-rendered terminal. No Electron, no subscription.

#### 7. eltociear/awesome-AI-driven-development (325 stars)

522 tools catalogued. cmux appears here. Has "Terminal & CLI Agents" and "Multi-Agent &
Orchestration" sections.

- **Section:** Multi-Agent & Orchestration
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  - [Factory Floor](https://github.com/alltuner/factoryfloor) - Native macOS workspace that orchestrates parallel Claude Code agents, each in its own git worktree with automatic dev server port detection. Built on libghostty for GPU-rendered terminals.
  ```

#### 8. jiji262/awesome-vibe-coding-tools (72 stars)

Emerging list. conductor.build appears here. Has "Multi-Agent Orchestration &
Collaboration" and "Task, Memory & Workspace Management" sections.

- **Section:** Multi-Agent Orchestration & Collaboration
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  - **[alltuner/factoryfloor](https://github.com/alltuner/factoryfloor):** Native macOS workspace for running multiple coding agents in parallel. Each workstream gets its own git worktree, Claude Code terminal (GPU-rendered via Ghostty), and embedded browser with automatic port detection. Keyboard-first, zero config.
  ```
- **Notes:** Small but growing. Low barrier to entry. Good for early positioning in the "vibe coding" category.

#### 9. jqueryscript/awesome-claude-code (213 stars)

Another awesome-claude-code list with a dedicated "Clients & GUIs" section listing
desktop apps like Claudiatron, Claude-Code-ChatInWindows, and ccmate.

- **Section:** Clients & GUIs
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  - [**Factory Floor**](https://github.com/alltuner/factoryfloor) - Native macOS workspace for running multiple Claude Code agents in parallel, each in its own git worktree with GPU-rendered terminals (libghostty) and automatic dev server detection.
  ```

#### 10. dictcp/awesome-git (2.8k stars)

General-purpose list of git tools. The angle here is worktree management.

- **Section:** Tools
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  * [Factory Floor](https://github.com/alltuner/factoryfloor) - macOS workspace that automates git worktree creation, switching, and cleanup. Each worktree gets its own terminal, AI agent, and dev server.
  ```
- **Notes:** This list hasn't been updated frequently. Check recent activity before investing effort.

#### 11. ai-for-developers/awesome-ai-coding-tools (1.6k stars)

Curated list of AI-powered coding tools.

- **How to submit:** Check their CONTRIBUTING.md or open a PR.
- **Ready-to-submit copy:**
  ```
  - [Factory Floor](https://factory-floor.com) - Native macOS workspace for parallel AI-assisted development. Manages git worktrees with integrated Claude Code agents, GPU-rendered terminals, and embedded dev servers.
  ```

#### 12. rothgar/awesome-tuis (18k stars)

Community-maintained list of TUI applications. cmux is listed here under Development.

- **Section:** Development
- **How to submit:** Open a PR.
- **Ready-to-submit copy:**
  ```
  - [Factory Floor](https://github.com/alltuner/factoryfloor) Developer workspace for parallel git worktrees with embedded terminal sessions, AI agents, and dev servers. macOS native.
  ```
- **Notes:** Borderline fit. Factory Floor is a GUI app, not a TUI. Only submit if the list shows precedent for GUI tools in the Development section.

### Directories and web listings

#### 13. awesomeclaude.ai

Curated web directory of Claude resources. Has an Applications section and Claude Code tools.

- **Section:** Applications or Claude Code tools
- **How to submit:** Unknown (no visible submission form). Likely contact the maintainer directly or check if there's a GitHub repo backing it.
- **Ready-to-submit copy:**
  - **Name:** Factory Floor
  - **URL:** https://factory-floor.com
  - **Repository:** https://github.com/alltuner/factoryfloor
  - **Description:** Native macOS workspace for running multiple Claude Code agents in parallel, each in its own git worktree with GPU-rendered terminals and automatic dev server detection.

### Lower priority

#### travisvn/awesome-claude-skills (9.6k stars)

Focused on Claude Skills for Claude Code CLI. Only worth it if they add an apps category.

#### sindresorhus/awesome (448k stars)

The meta-list. Not for individual tools. Worth knowing about if we ever create an
"awesome-worktrees" or "awesome-parallel-development" list.

## Submission Strategy

### Before submitting anywhere

1. **Polish the README** with clear description, screenshots/GIFs, and install instructions
2. **Website** (factory-floor.com) should have demo content and the /get/ page working
3. **GitHub repo hygiene**: topics set, social preview image, releases published
4. **Star count**: some lists have implicit minimum thresholds

### Submission order

1. **awesome-claude-code** (strongest fit, issue-based submission is low friction)
2. **awesome-libghostty** (perfect category match, competitors already listed)
3. **Awesome-Ghostty** (small community, quick turnaround, Ghostty ecosystem cred)
4. **awesome-mac** (highest reach, highest quality bar)
5. **developer-roadmap** (352k stars, huge visibility, small community tools section)
6. **openalternative.co** (SEO value, web submission form)
7. **awesome-AI-driven-development** and **awesome-vibe-coding-tools** (easy PRs, emerging lists)
8. Rest as time permits

### Link strategy

- **GitHub-focused lists** (awesome-claude-code, awesome-git, awesome-tuis, awesome-AI-driven-development, awesome-vibe-coding-tools, jqueryscript/awesome-claude-code): link to `https://github.com/alltuner/factoryfloor`
- **User-facing lists** (awesome-mac, awesome-libghostty, Awesome-Ghostty, awesome-ai-coding-tools): link to `https://factory-floor.com`
- **Directories** (openalternative.co, awesomeclaude.ai): provide both the website and repo URL
- **developer-roadmap**: link to repo (follows their `@opensource@` tag convention)

## Tracking

| List | Submitted | PR/Issue | Status |
|------|-----------|----------|--------|
| hesreallyhim/awesome-claude-code | | | |
| Uzaaft/awesome-libghostty | | | |
| wyattgill9/Awesome-Ghostty | | | |
| jaywcjlove/awesome-mac | | | |
| kamranahmedse/developer-roadmap | | | |
| openalternative.co | | | |
| eltociear/awesome-AI-driven-development | | | |
| jiji262/awesome-vibe-coding-tools | | | |
| jqueryscript/awesome-claude-code | | | |
| dictcp/awesome-git | | | |
| ai-for-developers/awesome-ai-coding-tools | | | |
| rothgar/awesome-tuis | | | |
| awesomeclaude.ai | | | |
