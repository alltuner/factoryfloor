---
title: Home
translationKey: home
---
<!-- Hero -->
<section class="min-h-screen flex flex-col justify-center relative pt-20 overflow-hidden">
  <div class="absolute -top-[30%] -right-[20%] w-[70%] h-[70%] rounded-full pointer-events-none animate-pulse-glow bg-[radial-gradient(ellipse,var(--color-wine-glow)_0%,transparent_70%)]"></div>

  <div class="max-w-[1100px] mx-auto px-8 w-full">
    <!-- Logo -->
    <svg class="w-20 h-20 mb-8 animate-fade-up" viewBox="0 0 250 249" xmlns="http://www.w3.org/2000/svg">
      <g transform="translate(105,100.5)">
        <g transform="matrix(1.6875,0,0,1.6877,-362.68,-21.43)">
          <path fill="#5b2333" d="m226.61-28.52a47.99 47.99 0 00-47.99 47.99 47.99 47.99 0 0043.18 47.65v-21a20.16 20.16 0 01-15.99-19.67l.01-.2h-.01v-19.78h8.35v19.79h.06a11.77 12.5 0 00-.02.19 11.77 12.5 0 0011.77 12.5 11.77 12.5 0 0011.77-12.5 11.77 12.5 0 00-.02-.19h.06v-9.28h8.35v9.27h-.01l.01.2a20.16 20.16 0 01-15.99 19.67v21.09a47.99 47.99 0 0044.46-47.74 47.99 47.99 0 00-47.99-47.99zm-20.8 12.8h8.35v12.38h-8.35zm31.98 0h8.35v22.89h-8.35zm-11.81 43.24a3.74 3.74 0 013.74 3.74 3.74 3.74 0 01-3.74 3.74 3.74 3.74 0 01-3.74-3.74 3.74 3.74 0 013.74-3.74z"/>
        </g>
        <path d="m-105.04 147.67v-5h12v5h3v-7h8l4-3 4 3 4-3 4 3v7h3v-18h4v18h4v-6h14v6h3v-8h28v8h3v-5h10v5h2v-16h4v16h3v-7l5-3 5 3 5-3 5 3 5-3 5 3v7h4c0-32 8-44 11-44 3 0 11 12 11 44h3v-6h16v6h2v-8h26v8h3v-4h8v4h2v-14h4v14h3v-6h10v6z" fill="#5b2333" stroke="#5b2333" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </g>
    </svg>

    <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full font-mono text-xs text-fg-muted mb-8 border border-fg-faint bg-fg-faint animate-fade-up">
      <span class="w-1.5 h-1.5 bg-wine-light rounded-full animate-blink"></span>
      macOS native &middot; Ghostty terminal &middot; Claude Code
    </div>

    <h1 class="font-mono font-bold leading-[1.05] tracking-tighter mb-6 animate-fade-up-1 text-[clamp(3rem,7vw,5.5rem)]">
      Your <span class="bg-gradient-to-br from-wine-light to-[#9e4a60] bg-clip-text text-transparent">AI&#8209;powered</span><br>
      dev workspace.
    </h1>

    <p class="text-lg text-fg-muted max-w-[540px] leading-relaxed mb-10 animate-fade-up-2">
      A native macOS app built on <a href="https://ghostty.org" class="text-wine-light hover:underline">Ghostty</a>'s
      GPU-rendered terminal. Manages git worktrees, Claude Code sessions,
      and dev servers from a single window. Each workstream gets its own
      branch, terminal, and AI agent &mdash; all running in parallel,
      all at native speed.
    </p>

    <div class="flex gap-4 flex-wrap animate-fade-up-3">
      <a href="https://github.com/anthropics/ff2/releases" class="inline-flex items-center gap-2 bg-wine text-[#F7F4F3] px-6 py-3 rounded-lg font-mono text-sm font-medium border border-wine-light no-underline transition-all hover:bg-wine-light hover:-translate-y-0.5 hover:shadow-[0_8px_30px_var(--color-wine-glow)]">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        Download
      </a>
      <a href="https://github.com/anthropics/ff2" class="inline-flex items-center gap-2 bg-transparent text-fg-dim px-6 py-3 rounded-lg font-mono text-sm border border-fg-faint no-underline transition-all hover:-translate-y-0.5 hover:bg-fg-faint">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/></svg>
        View source
      </a>
    </div>

    <!-- Terminal preview -->
    <div class="mt-16 rounded-xl overflow-hidden border border-fg-faint bg-bg-surface shadow-[0_25px_80px_var(--color-shadow)] animate-fade-up-4">
      <div class="flex items-center gap-1.5 px-4 py-3 bg-bg-elevated border-b border-fg-faint">
        <span class="w-2.5 h-2.5 rounded-full bg-[#ff5f57]"></span>
        <span class="w-2.5 h-2.5 rounded-full bg-[#febc2e]"></span>
        <span class="w-2.5 h-2.5 rounded-full bg-[#28c840]"></span>
        <span class="flex-1 text-center font-mono text-[0.7rem] text-fg-muted mr-12">Factory Floor &mdash; my-project &mdash; deploy-auth-fix</span>
      </div>
      <div class="flex gap-0 px-3 bg-bg-surface/60 border-b border-fg-faint">
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg-muted border-b-2 border-transparent">Info</span>
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg border-b-2 border-wine-light bg-fg-faint/30">Coding Agent</span>
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg-muted border-b-2 border-transparent">Terminal</span>
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg-muted border-b-2 border-transparent">Browser</span>
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg-muted border-b-2 border-transparent">Setup</span>
        <span class="px-3.5 py-2 font-mono text-[0.7rem] text-fg-muted border-b-2 border-transparent">Run</span>
      </div>
      <div class="p-5 font-mono text-[0.8rem] leading-loose min-h-[180px]">
        <div><span class="text-wine-light">$</span> <span>claude</span> <span class="text-fg-muted">--resume</span> <span class="text-code-key">a1b2c3d4</span> <span class="text-fg-muted">--name</span> <span class="text-code-key">deploy-auth-fix</span></div>
        <div class="text-fg-muted">Resuming session...</div>
        <div>&nbsp;</div>
        <div><span class="text-code-str">claude</span> <span class="text-fg-muted">Fix the authentication timeout bug in the login handler.</span></div>
        <div class="text-fg-muted">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The JWT expiry check is using seconds instead of milliseconds.</div>
        <div>&nbsp;</div>
        <div><span class="text-code-str">&#10003;</span> <span class="text-fg-muted">Reading src/auth/handler.ts</span></div>
        <div><span class="text-code-str">&#10003;</span> <span class="text-fg-muted">Editing token validation logic</span></div>
        <div><span class="text-code-str">&#10003;</span> <span class="text-fg-muted">Running tests... 47 passed</span></div>
        <div><span class="text-wine-light">$</span> <span class="inline-block w-2 h-4 bg-fg align-text-bottom animate-cursor"></span></div>
      </div>
    </div>
  </div>
</section>

<div class="divider"></div>

<!-- Features -->
<section id="features" class="py-24">
  <div class="max-w-[1100px] mx-auto px-8">
    <div class="reveal">
      <div class="font-mono text-[0.7rem] font-semibold uppercase tracking-widest text-wine-light mb-4">Features</div>
      <h2 class="font-mono text-[clamp(1.6rem,3.5vw,2.2rem)] font-bold tracking-tight mb-4 leading-tight">Everything in one window.</h2>
      <p class="text-fg-muted max-w-[560px] leading-relaxed">No more juggling terminals, browsers, and git clients. Each workstream is a self-contained development environment.</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-px mt-14 rounded-xl overflow-hidden border border-fg-faint bg-fg-faint reveal">
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#9735;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Git Worktrees</h3>
        <p class="text-sm text-fg-muted leading-relaxed">Each workstream gets its own branch and worktree. Switch between tasks without stashing, with .env files automatically symlinked.</p>
      </div>
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#9672;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Claude Code</h3>
        <p class="text-sm text-fg-muted leading-relaxed">Integrated AI agent with session persistence. Resume conversations across app restarts with automatic session IDs.</p>
      </div>
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#9638;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Tmux Persistence</h3>
        <p class="text-sm text-fg-muted leading-relaxed">Agent sessions survive app restarts via tmux on a dedicated socket. No more lost context or interrupted workflows.</p>
      </div>
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#9881;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Setup &amp; Run Scripts</h3>
        <p class="text-sm text-fg-muted leading-relaxed">Configure setup, run, and teardown scripts per project. Compatible with emdash, conductor, and superset configs.</p>
      </div>
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#9741;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Embedded Browser</h3>
        <p class="text-sm text-fg-muted leading-relaxed">WKWebView browser tab with deterministic port allocation. Preview your app without leaving the workspace.</p>
      </div>
      <div class="p-8 bg-bg transition-colors hover:bg-bg-surface">
        <div class="w-10 h-10 flex items-center justify-center rounded-[10px] border border-wine/30 bg-wine-glow mb-5 text-lg">&#10022;</div>
        <h3 class="font-mono text-sm font-semibold mb-2">GitHub Integration</h3>
        <p class="text-sm text-fg-muted leading-relaxed">See repo info, open PRs, and branch PR status directly in the project view. Powered by the gh CLI.</p>
      </div>
    </div>
  </div>
</section>

<div class="divider"></div>

<!-- How it works -->
<section id="how-it-works" class="py-24">
  <div class="max-w-[1100px] mx-auto px-8">
    <div class="reveal">
      <div class="font-mono text-[0.7rem] font-semibold uppercase tracking-widest text-wine-light mb-4">How it works</div>
      <h2 class="font-mono text-[clamp(1.6rem,3.5vw,2.2rem)] font-bold tracking-tight mb-4 leading-tight">Three steps to parallel development.</h2>
      <p class="text-fg-muted max-w-[560px] leading-relaxed">Go from repo to running workstream in seconds. Each workstream is isolated and self-contained.</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mt-14 relative steps-container reveal">
      <div class="text-center relative">
        <div class="w-12 h-12 flex items-center justify-center mx-auto mb-6 rounded-full border-2 border-wine bg-bg font-mono font-bold text-wine-light relative z-10">1</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Add a project</h3>
        <p class="text-sm text-fg-muted leading-relaxed">Drop a directory on the sidebar, or create a new one. ff2 detects git repos, installed tools, and GitHub connections automatically.</p>
      </div>
      <div class="text-center relative">
        <div class="w-12 h-12 flex items-center justify-center mx-auto mb-6 rounded-full border-2 border-wine bg-bg font-mono font-bold text-wine-light relative z-10">2</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Create a workstream</h3>
        <p class="text-sm text-fg-muted leading-relaxed">A new git worktree with a fresh branch, a Claude Code session, a terminal, and a browser tab. All wired up and ready to go.</p>
      </div>
      <div class="text-center relative">
        <div class="w-12 h-12 flex items-center justify-center mx-auto mb-6 rounded-full border-2 border-wine bg-bg font-mono font-bold text-wine-light relative z-10">3</div>
        <h3 class="font-mono text-sm font-semibold mb-2">Code with AI</h3>
        <p class="text-sm text-fg-muted leading-relaxed">The coding agent renames your branch to match the task. Setup scripts install dependencies. Switch between workstreams without losing state.</p>
      </div>
    </div>
  </div>
</section>

<div class="divider"></div>

<!-- Config -->
<section id="config" class="py-24">
  <div class="max-w-[1100px] mx-auto px-8">
    <div class="reveal">
      <div class="font-mono text-[0.7rem] font-semibold uppercase tracking-widest text-wine-light mb-4">Configuration</div>
      <h2 class="font-mono text-[clamp(1.6rem,3.5vw,2.2rem)] font-bold tracking-tight mb-4 leading-tight">Drop-in script config.</h2>
      <p class="text-fg-muted max-w-[560px] leading-relaxed">
        Automate your workstream lifecycle with setup, run, and teardown scripts.
        Install dependencies when a worktree is created, start dev servers on demand,
        and clean up resources when archiving. Add a
        <code class="font-mono text-[0.9em] px-1.5 py-0.5 rounded bg-bg-elevated">.factoryfloor.json</code>
        to your repo, or use your existing config from
        <a href="https://emdash.sh" class="text-wine-light hover:underline">emdash</a>,
        <a href="https://conductor.build" class="text-wine-light hover:underline">conductor</a>, or
        <a href="https://superset.sh" class="text-wine-light hover:underline">superset</a>.
      </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mt-14 items-start reveal">
      <div class="rounded-[10px] overflow-hidden border border-fg-faint bg-bg-surface">
        <div class="flex items-center justify-between px-4 py-3 bg-bg-elevated border-b border-fg-faint font-mono text-[0.7rem] text-fg-muted">
          <span>.factoryfloor.json</span>
          <span class="opacity-50">project root</span>
        </div>
        <pre class="p-5 font-mono text-[0.78rem] leading-relaxed overflow-x-auto"><code><span class="text-fg-muted">{</span>
  <span class="text-code-key">"setup"</span><span class="text-fg-muted">:</span> <span class="text-code-str">"npm install"</span><span class="text-fg-muted">,</span>
  <span class="text-code-key">"run"</span><span class="text-fg-muted">:</span> <span class="text-code-str">"PORT=$FF_PORT npm run dev"</span><span class="text-fg-muted">,</span>
  <span class="text-code-key">"teardown"</span><span class="text-fg-muted">:</span> <span class="text-code-str">"docker-compose down"</span>
<span class="text-fg-muted">}</span></code></pre>
      </div>

      <div>
        <p class="text-sm text-fg-muted leading-relaxed mb-6">No config file? ff2 looks for these formats in order:</p>
        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-4 p-4 rounded-lg border border-fg-faint bg-bg-surface">
            <span class="font-mono text-[0.7rem] font-semibold text-wine-light w-6 shrink-0">1</span>
            <div>
              <h4 class="font-mono text-sm font-medium">.factoryfloor.json</h4>
              <p class="text-xs text-fg-muted">Native config with setup, run, teardown</p>
            </div>
          </div>
          <a href="https://emdash.sh" class="flex items-center gap-4 p-4 rounded-lg border border-fg-faint bg-bg-surface no-underline text-fg transition-colors hover:border-fg-muted/30">
            <span class="font-mono text-[0.7rem] font-semibold text-wine-light w-6 shrink-0">2</span>
            <div>
              <h4 class="font-mono text-sm font-medium">.emdash.json</h4>
              <p class="text-xs text-fg-muted">emdash.sh format (scripts object)</p>
            </div>
          </a>
          <a href="https://conductor.build" class="flex items-center gap-4 p-4 rounded-lg border border-fg-faint bg-bg-surface no-underline text-fg transition-colors hover:border-fg-muted/30">
            <span class="font-mono text-[0.7rem] font-semibold text-wine-light w-6 shrink-0">3</span>
            <div>
              <h4 class="font-mono text-sm font-medium">conductor.json</h4>
              <p class="text-xs text-fg-muted">conductor.build format (scripts.archive for teardown)</p>
            </div>
          </a>
          <a href="https://superset.sh" class="flex items-center gap-4 p-4 rounded-lg border border-fg-faint bg-bg-surface no-underline text-fg transition-colors hover:border-fg-muted/30">
            <span class="font-mono text-[0.7rem] font-semibold text-wine-light w-6 shrink-0">4</span>
            <div>
              <h4 class="font-mono text-sm font-medium">.superset/config.json</h4>
              <p class="text-xs text-fg-muted">superset.sh format (arrays, no run command)</p>
            </div>
          </a>
        </div>
      </div>
    </div>
  </div>
</section>

<div class="divider"></div>

<!-- Environment Variables -->
<section id="env" class="py-24">
  <div class="max-w-[1100px] mx-auto px-8">
    <div class="reveal">
      <div class="font-mono text-[0.7rem] font-semibold uppercase tracking-widest text-wine-light mb-4">Environment</div>
      <h2 class="font-mono text-[clamp(1.6rem,3.5vw,2.2rem)] font-bold tracking-tight mb-4 leading-tight">Variables available in every terminal.</h2>
      <p class="text-fg-muted max-w-[560px] leading-relaxed">Every workstream terminal, setup script, and run command has access to these environment variables. Use them in your scripts and dev server configs.</p>
    </div>

    <div class="mt-14 rounded-xl overflow-hidden border border-fg-faint bg-bg-surface reveal">
      <table class="w-full text-left">
        <thead>
          <tr class="border-b border-fg-faint bg-bg-elevated">
            <th class="px-6 py-3 font-mono text-xs font-semibold text-fg-muted">Variable</th>
            <th class="px-6 py-3 font-mono text-xs font-semibold text-fg-muted">Description</th>
            <th class="px-6 py-3 font-mono text-xs font-semibold text-fg-muted hidden md:table-cell">Example</th>
          </tr>
        </thead>
        <tbody class="font-mono text-sm">
          <tr class="border-b border-fg-faint">
            <td class="px-6 py-3 text-wine-light text-xs">FF_PROJECT</td>
            <td class="px-6 py-3 font-sans text-sm text-fg-dim">Project name</td>
            <td class="px-6 py-3 text-xs text-fg-muted hidden md:table-cell">my-app</td>
          </tr>
          <tr class="border-b border-fg-faint">
            <td class="px-6 py-3 text-wine-light text-xs">FF_WORKSTREAM</td>
            <td class="px-6 py-3 font-sans text-sm text-fg-dim">Workstream name</td>
            <td class="px-6 py-3 text-xs text-fg-muted hidden md:table-cell">deploy-auth-fix</td>
          </tr>
          <tr class="border-b border-fg-faint">
            <td class="px-6 py-3 text-wine-light text-xs">FF_PROJECT_DIR</td>
            <td class="px-6 py-3 font-sans text-sm text-fg-dim">Main repository path</td>
            <td class="px-6 py-3 text-xs text-fg-muted hidden md:table-cell">~/repos/my-app</td>
          </tr>
          <tr class="border-b border-fg-faint">
            <td class="px-6 py-3 text-wine-light text-xs">FF_WORKTREE_DIR</td>
            <td class="px-6 py-3 font-sans text-sm text-fg-dim">Worktree path for this workstream</td>
            <td class="px-6 py-3 text-xs text-fg-muted hidden md:table-cell">~/.ff2/worktrees/my-app/deploy-auth-fix</td>
          </tr>
          <tr>
            <td class="px-6 py-3 text-wine-light text-xs">FF_PORT</td>
            <td class="px-6 py-3 font-sans text-sm text-fg-dim">Deterministic port for this workstream</td>
            <td class="px-6 py-3 text-xs text-fg-muted hidden md:table-cell">42017</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</section>

<div class="divider"></div>

<!-- Shortcuts -->
<section id="shortcuts" class="py-24">
  <div class="max-w-[1100px] mx-auto px-8">
    <div class="reveal">
      <div class="font-mono text-[0.7rem] font-semibold uppercase tracking-widest text-wine-light mb-4">Keyboard-first</div>
      <h2 class="font-mono text-[clamp(1.6rem,3.5vw,2.2rem)] font-bold tracking-tight mb-4 leading-tight">Navigate without the mouse.</h2>
      <p class="text-fg-muted max-w-[560px] leading-relaxed">Context-sensitive shortcuts that adapt to whether you're in a project view or a workstream.</p>
    </div>

    <div class="reveal">
      <div class="mt-14">
        <h3 class="font-mono text-xs font-semibold uppercase tracking-wide text-wine-light mb-2 pl-2">Global</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-px rounded-xl overflow-hidden border border-fg-faint bg-fg-faint">
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">New workstream or project</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">N</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Settings</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">,</kbd></span>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h3 class="font-mono text-xs font-semibold uppercase tracking-wide text-wine-light mb-2 pl-2">Project view</h3>
        <div class="grid grid-cols-1 gap-px rounded-xl overflow-hidden border border-fg-faint bg-fg-faint">
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Open workstream by position</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">1-9</kbd></span>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h3 class="font-mono text-xs font-semibold uppercase tracking-wide text-wine-light mb-2 pl-2">Workstream view</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-px rounded-xl overflow-hidden border border-fg-faint bg-fg-faint">
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Back to project</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">0</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Info / Agent / Terminal / Browser</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">1-4</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Setup / Run</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">5-6</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">Cycle tabs</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8679;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">[ ]</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">External browser</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8679;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">O</kbd></span>
          </div>
          <div class="flex items-center justify-between px-6 py-4 bg-bg transition-colors hover:bg-bg-surface">
            <span class="text-sm text-fg-dim">External terminal</span>
            <span class="flex gap-1"><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8984;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">&#8679;</kbd><kbd class="inline-flex items-center justify-center min-w-7 h-[26px] px-1.5 rounded bg-bg-elevated border-b-2 border-fg-faint font-mono text-[0.7rem] text-fg-dim">E</kbd></span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

