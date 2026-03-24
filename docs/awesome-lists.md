# Awesome Lists Submission Guide

Where to list Factory Floor and how to get featured.

## Priority Targets

### Tier 1: High-impact, strong fit

#### 1. hesreallyhim/awesome-claude-code (31k stars)

The most relevant list. Factory Floor fits squarely in the **"Alternative Clients"** section,
alongside similar tools like crystal (desktop orchestrator), claude-tmux (tmux-based session
management with worktree support), and Omnara (command center for AI agents).

- **Section:** Tooling > Alternative Clients > General
- **How to submit:** Open an issue using their [recommend-resource template](https://github.com/hesreallyhim/awesome-claude-code/issues/new?template=recommend-resource.yml). Do NOT open a PR; their automated system (Claude-managed) handles all PRs.
- **Pitch angle:** Native macOS app that combines git worktrees + Claude Code + dev servers in a single GPU-rendered window. Differentiator vs crystal/Omnara: native (not Electron), Ghostty-powered terminals, built-in port detection for dev servers.
- **Competitors already listed:** crystal, claude-tmux, Omnara, Claudable, claude-esp

#### 2. jaywcjlove/awesome-mac (101k stars)

Massive reach. Factory Floor fits in **Developer Tools > Terminal Apps** or possibly
**Developer Tools > Developer Utilities**.

- **Section:** Developer Tools > Terminal Apps (best fit)
- **How to submit:** Open a PR adding Factory Floor to the appropriate section. Read their [contributing guidelines](https://github.com/jaywcjlove/awesome-mac/blob/master/CONTRIBUTING.md) first. Uses badges for open source, freeware, and App Store links.
- **Format:** Follow their entry format exactly:
  ```
  * [Factory Floor](https://factory-floor.com) - Native macOS workspace for parallel development with git worktrees, Claude Code, and embedded dev servers. [![Open Source Software](badge-url)](https://github.com/alltuner/factoryfloor) [![Freeware](badge-url)]
  ```
- **Notes:** This list is highly curated and well-maintained. Quality bar is high; the app should be polished and have a good README/website.

#### 3. Uzaaft/awesome-libghostty (354 stars)

Curated list of projects built with libghostty. Has a dedicated **"AI Tools & Agent
Orchestration"** section that is the perfect home for Factory Floor. Direct competitors
already listed: cmux, Commander, Mux, Supacode, Aizen.

- **Section:** AI Tools & Agent Orchestration
- **How to submit:** Open a PR. See [CONTRIBUTING.md](https://github.com/Uzaaft/awesome-libghostty/blob/master/CONTRIBUTING.md) for guidelines.
- **Pitch angle:** Native macOS workspace for parallel development with git worktrees, Claude Code, and embedded dev servers, powered by libghostty.
- **Format:** Match existing entries:
  ```
  * [Factory Floor](https://factory-floor.com) - A native macOS workspace for parallel development with git worktrees, Claude Code terminals, and embedded dev servers.
  ```
- **Notes:** This is the most natural fit of all lists. Factory Floor is literally built on libghostty, and the section already contains its closest competitors. Should be one of the first submissions.

#### 4. wyattgill9/Awesome-Ghostty (active fork, 252+ stars)

Previously fearlessgeekmedia/Awesome-Ghostty (now archived, redirects to this fork).

- **Section:** Tools (most appropriate; lists tools that integrate with Ghostty)
- **How to submit:** Open a PR. The list accepts direct PRs with new entries.
- **Pitch angle:** Factory Floor embeds Ghostty (via libghostty xcframework) as its terminal backend. It's a native macOS app built on top of Ghostty's GPU-rendered terminal.
- **Format:**
  ```
  * [Factory Floor](https://factory-floor.com) - Native macOS workspace for parallel development, embedding Ghostty terminals with git worktrees and Claude Code integration.
  ```
- **Notes:** Smaller list but targeted. Being listed here signals legitimacy in the Ghostty ecosystem. Some overlap with awesome-libghostty, but different audience.

### Tier 2: Good fit, worth pursuing

#### 4. rothgar/awesome-tuis (18k stars)

Community-maintained list of TUI applications. cmux is listed here under Development.
Factory Floor is a GUI app, not a TUI, so the fit is debatable, but the list does include
tools with graphical elements that run alongside terminals.

- **Section:** Development
- **How to submit:** Open a PR. Simple policy: "If you have a cool tool you'd like to share please open a PR."
- **Pitch angle:** Developer workspace with embedded terminal UIs for managing parallel Claude Code agents in git worktrees.
- **Worth it?** Borderline. Factory Floor is native macOS GUI, not a TUI. Only submit if the list shows precedent for GUI tools in the Development section.

#### 5. eltociear/awesome-AI-driven-development (325 stars)

522 tools catalogued. Has both "Terminal & CLI Agents" and "Multi-Agent & Orchestration"
sections. cmux appears here. Covers the full AI dev tool landscape.

- **Section:** Multi-Agent & Orchestration (best fit)
- **How to submit:** Open a PR
- **Pitch angle:** Native macOS orchestration for parallel Claude Code agents, each in its own git worktree with dev server port detection.

#### 6. jiji262/awesome-vibe-coding-tools (72 stars)

Emerging list with sections for "Multi-Agent Orchestration & Collaboration" and
"Task, Memory & Workspace Management". conductor.build appears here.

- **Section:** Multi-Agent Orchestration & Collaboration, or Task, Memory & Workspace Management
- **How to submit:** Open a PR
- **Pitch angle:** Workspace manager for parallel vibe coding: git worktrees + Claude Code + embedded dev servers in a single native window.
- **Notes:** Small but growing. Low barrier to entry. Good for early positioning in the "vibe coding" category.

#### 7. jqueryscript/awesome-claude-code (213 stars)

Another awesome-claude-code list. Has a dedicated "Clients & GUIs" section listing
desktop apps like Claudiatron, Claude-Code-ChatInWindows, and ccmate.

- **Section:** Clients & GUIs
- **How to submit:** Open a PR
- **Pitch angle:** Native macOS GUI for orchestrating Claude Code with git worktrees and embedded dev servers.
- **Notes:** Smaller than hesreallyhim's list but has a dedicated GUI category that's a natural fit.

#### 8. dictcp/awesome-git (2.8k stars)

General-purpose list of git tools, resources, and extensions.

- **Section:** Tools or Extensions (Factory Floor's worktree management is the angle)
- **How to submit:** Open a PR. Simple contributing policy: "Pull requests on interesting tools/projects/resources are welcome."
- **Pitch angle:** Git worktree management GUI. Factory Floor automates `git worktree add/remove` and provides a visual interface for managing multiple parallel workstreams.
- **Format:**
  ```
  * [Factory Floor](https://github.com/alltuner/factoryfloor) - Native macOS workspace that automates git worktree management with integrated terminals and dev servers
  ```
- **Notes:** This list hasn't been updated frequently. Check recent activity before investing effort.

#### 9. ai-for-developers/awesome-ai-coding-tools (1.6k stars)

Curated list of AI-powered coding tools.

- **Section:** Likely has categories for IDEs/editors or development environments
- **How to submit:** Check their CONTRIBUTING.md or open a PR
- **Pitch angle:** Development workspace optimized for AI-assisted parallel coding with Claude Code

### Directories and non-GitHub listings

#### 10. awesomeclaude.ai

Curated web directory of Claude-related resources. Organized by categories (Official,
Applications, Tools, etc.). Has a Claude Code section with tools and integrations.

- **Section:** Applications or Claude Code tools
- **How to submit:** Unknown (no visible submission form). Likely contact the maintainer directly or check if there's a GitHub repo backing it.
- **Pitch angle:** Native macOS workspace for parallel Claude Code development.
- **Notes:** Well-organized, high-quality directory. Worth investigating the submission process.

#### 11. openalternative.co (5.7k stars on GitHub)

Open source alternatives directory. Curated list of open source alternatives to proprietary
software. superset.sh is listed here.

- **Section:** Developer Tools (as an open source alternative to proprietary dev environments)
- **How to submit:** Submit at [openalternative.co/submit](https://openalternative.co/submit). Approved tools automatically appear in the GitHub repo.
- **Pitch angle:** Open source alternative to proprietary parallel development environments. Native macOS, no Electron, no subscription.
- **Notes:** Good SEO. Appearing here drives organic traffic from people searching for open source dev tools.

#### 12. kamranahmedse/developer-roadmap (352k stars)

The most popular developer resource on GitHub. Has a Claude Code roadmap section with a
"Community Tools" page. conductor.build is already featured there.

- **Section:** Claude Code roadmap > Community Tools
- **How to submit:** Open a PR modifying the community tools content file. Very high visibility.
- **Pitch angle:** Parallel development workspace for Claude Code with git worktrees and dev server integration.
- **Notes:** Extremely high visibility (352k stars). The Claude Code community tools section is small (currently just Conductor), so there's room. But the quality bar and review process will be strict.

### Tier 3: Lower priority

#### travisvn/awesome-claude-skills (9.6k stars)

Focused on Claude Skills for Claude Code CLI. Only worth it if they add an apps category.

#### sindresorhus/awesome (448k stars)

The meta-list of awesome lists. Not a place to list individual tools, but worth knowing about
if we ever wanted to create our own "awesome-worktrees" or similar list.

## Submission Strategy

### Before submitting anywhere

1. **Polish the README** - clear description, screenshots/GIFs, installation instructions
2. **Have a working website** (factory-floor.com) with demo content
3. **GitHub repo hygiene** - topics set, social preview image, releases published
4. **Star count matters** - some lists have minimum thresholds (explicit or implicit)

### Submission order

1. **awesome-claude-code** first (strongest fit, issue-based submission is low friction)
2. **awesome-libghostty** second (perfect category match, competitors already listed)
3. **Awesome-Ghostty** third (small community, quick turnaround, Ghostty ecosystem cred)
4. **awesome-mac** fourth (highest reach, but highest quality bar)
5. **developer-roadmap** fifth (352k stars, huge visibility, small community tools section)
6. **openalternative.co** sixth (SEO value, web submission form)
7. **awesome-AI-driven-development** and **awesome-vibe-coding-tools** (easy PRs, emerging lists)
8. Rest as time permits

### Description templates

**Short (one-liner):**
> Native macOS workspace for parallel development with git worktrees, Claude Code, and embedded dev servers.

**Medium (two sentences):**
> Native macOS workspace that combines git worktrees, Claude Code terminals, and embedded dev servers in a single GPU-rendered window. Run multiple AI coding agents simultaneously, each in its own isolated worktree with automatic port detection.

**Differentiators to emphasize per list:**
- awesome-claude-code: parallel Claude Code agents, worktree isolation, native macOS
- awesome-libghostty: built on libghostty, AI agent orchestration, worktree lifecycle
- Awesome-Ghostty: built on libghostty, GPU-rendered terminals, native macOS integration
- awesome-mac: native (not Electron), open source, developer productivity
- awesome-git: automated worktree lifecycle, visual worktree management
- developer-roadmap: community tool extending Claude Code with parallel workspaces
- openalternative: open source, no subscription, native macOS alternative
- awesome-vibe-coding: multi-agent orchestration, workspace management, parallel coding
- awesome-AI-driven-dev: multi-agent orchestration for AI-driven development
- awesomeclaude.ai: Claude Code workspace, parallel agent management

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
| rothgar/awesome-tuis | | | |
| jqueryscript/awesome-claude-code | | | |
| dictcp/awesome-git | | | |
| ai-for-developers/awesome-ai-coding-tools | | | |
| awesomeclaude.ai | | | |
