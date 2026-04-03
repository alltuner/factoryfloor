---
title: Docs
translationKey: docs
hideInstall: true
layout: docs
---

## Komma igång {#getting-started}

Vi skriver 2026. Vi bygger på tmux (2007), git worktrees (2015), terminals (1978, VT100-eran, när till och med [David](https://davidpoblador.com) bara var ett framtida projekt), och GPU-rendering (tack [Mitchell](https://mitchellh.com) för [Ghostty](https://ghostty.org)). Gamla verktyg, nya trick.

Du behöver två saker: en Mac och en vag känsla av att ditt nuvarande arbetsflöde kunde vara bättre.

```
brew install --cask factory-floor
```

<a href="https://github.com/alltuner/factoryfloor/releases/latest/download/FactoryFloor.dmg" class="docs-download"><svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Ladda ner DMG</a>

Factory Floor fungerar bäst när dessa är installerade (appen berättar om något saknas):

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — hela poängen, egentligen
- **git** — du har förmodligen redan detta
- **[gh](https://cli.github.com/)** — GitHub CLI, för PR-status och quick actions
- **[tmux](https://github.com/tmux/tmux)** — valfritt, möjliggör sessionspersistens

#### Dina första 30 sekunder {#your-first-30-seconds}

1. Öppna Factory Floor
2. Dra ett git-repository till sidebar (eller klicka **+** för att välja ett)
3. Tryck **⌘N** för att skapa en workstream
4. Klart. Du kodar med AI nu.

Inga konfigurationsfiler behövs. Factory Floor upptäcker din git-konfiguration, installerade verktyg och GitHub-anslutningar automatiskt.

---

## Grundläggande koncept {#core-concepts}

De tre sakerna du kommer att interagera med varje dag.

### Projekt {#projects}

Ett projekt är ett git-repository. Dra en katalog till sidebar eller klicka på **+**-knappen. Factory Floor kontrollerar om det är ett git-repo (och erbjuder att initiera ett om det inte är det).

Projektöversikten visar repository-info, GitHub-detaljer (stjärnor, forks, öppna issues), upp till 5 senaste PRs, och automatiskt upptäckt markdown-dokumentation från ditt repo.

Projekt sorteras efter **Senaste** (senaste aktivitet) som standard. Byt till **A-Ö** om du är en sån person.

Högerklicka på ett projekt i sidebar för snabb åtkomst: **Visa i Finder**, **Öppna i extern Terminal**, **Öppna på GitHub**, eller **Ta bort** (filerna finns kvar på disken, vi är inga monster).

### Workstreams {#workstreams}

En workstream är där arbetet sker. Varje workstream får sin egen git worktree, branch, terminal, coding agent och browser tab. De är helt isolerade från varandra.

**⌘N** skapar en ny workstream. Bakom kulisserna:

1. Hämtar senaste default branch från origin
2. Skapar en git worktree med en ny branch (med ditt branch-prefix, standard: `ff`)
3. Symlinks `.env` och `.env.local` från huvudrepot (om aktiverat)
4. Kör setup-scriptet (om konfigurerat)
5. Startar coding agent

Gränssnittet dyker upp direkt, worktree-skapandet sker i bakgrunden.

#### Workstream tabs {#workstream-tabs}

- **Info** (⌘I) — branch-namn, PR-status, projektdokumentation
- **Agent** (⌘Return) — din Claude Code-session
- **Environment** (⌘E) — setup- och run-scriptkontroller
- **Terminal** (⌘T) — ytterligare terminal tabs, så många du vill
- **Browser** (⌘B) — inbäddad browser med automatisk port-detection

#### Branch auto-rename {#branch-auto-rename}

Med **Auto-rename branch** aktiverat i inställningarna byter coding agent namn på din branch för att matcha uppgiften vid första prompten. Så `ff/coral-tidal-reef` blir `ff/fix-login-timeout`.

#### Ta bort vs. rensa {#removing-vs-purging}

- **Remove** — stänger terminals och agent, men worktree finns kvar på disken
- **Purge** — raderar permanent worktree och branch (frågar om bekräftelse om det finns uncommittade ändringar)

När en PR är mergad visar Factory Floor en "Purge" badge så att du vet att det är säkert att städa upp.

### Coding Agent {#the-coding-agent}

Coding Agent-tabben kör [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) i en inbäddad terminal. Den sitter direkt efter Info-tabben i varje workstream.

#### Agent-inställningar {#agent-settings}

- **Bypass permission prompts** — hoppar över bekräftelsedialoger. Användbart om du litar på din agent (och lever farligt).
- **Tmux mode** — kapslar agent-sessioner i tmux så de överlever omstarter av appen. Kräver tmux.
- **Auto-rename branch** — låter agenten byta namn på branch för att matcha uppgiften.
- **Agent Teams** — experimentell multi-agent-koordinering, med vänlig hälsning från Claude Code. Vi litar på Anthropic, eller hur?

#### Quick actions {#quick-actions}

Quick actions kör engångs-Claude-uppgifter från sidebar:

- **Commit** — stagear och committar med ett AI-genererat meddelande
- **Push** — pushar nuvarande branch till origin
- **Create PR** — skapar en pull request med AI-genererad titel och beskrivning
- **Abandon PR** — stänger PRn

Dessa körs som bakgrunds-`claude -p`-anrop. Aktivera **Quick action debug mode** i inställningarna om du vill veta hur korven görs. Lita på oss, [David](https://davidpoblador.com) lade ner mer tid än han vill erkänna på att debugga konstiga beteenden där inne.

---

## Din arbetsyta {#your-workspace}

Terminals, browsers och kortkommandon, verktygen inuti varje workstream.

### Terminals {#terminals}

Terminals är GPU-renderade via [Ghostty](https://ghostty.org). De är snabba.

- **⌘T** — ny terminal tab
- **⌘W** — stäng tab (eller Ctrl+D för att avsluta shell)
- **⌘1-9** — växla mellan tabs
- **⌘Shift+[** / **⌘Shift+]** — bläddra genom tabs

Du kan dra filer och text till terminal. För ibland är musen helt okej, faktiskt.

**⌘Shift+E** öppnar workstream-katalogen i din föredragna externa terminal-app.

### Browser {#the-browser}

Varje workstream kan ha browser tabs (⌘B). Browser är inbäddad, inget fönsterbyte behövs.

#### Port detection {#port-detection}

När ditt run-script startar en dev-server upptäcker Factory Floor den lyssnande porten automatiskt och navigerar browser dit. Ingen konfiguration behövs. `ff-run`-launchern övervakar processträdet efter TCP-lyssnare.

#### Navigering {#navigation}

- **⌘L** — fokusera adressfältet
- **⌘Shift+O** — öppna aktuell URL i din externa browser
- **⌘Click** — öppnar länkar i din externa browser

Browser visar en anslutningsfel-sida med en retry-knapp om servern inte är redo ännu. Den auto-navigerar när porten upptäcks.

### Tangentbordsgenvägar {#keyboard-shortcuts}

Factory Floor är tangentbord-först. Här är allt.

#### Globala {#global}

| Genväg | Åtgärd |
|----------|--------|
| ⌘N | Ny workstream (eller projekt, om inga finns) |
| ⌘Shift+N | Nytt projekt |
| ⌘, | Inställningar |
| ⌘/ | Hjälp |

#### Workstream {#workstream}

| Genväg | Åtgärd |
|----------|--------|
| ⌘Return | Fokusera Coding Agent |
| ⌘I | Info-panel |
| ⌘E | Environment |
| ⌘T | Ny Terminal |
| ⌘B | Ny Browser |
| ⌘W | Stäng tab |
| ⌘L | Adressfält (browser) |
| ⌘0 | Tillbaka till projekt |
| ⌘1-9 | Byt tab |
| ⌘Shift+[ | Föregående tab |
| ⌘Shift+] | Nästa tab |
| Ctrl+Shift+R | Bygg om setup |
| Ctrl+Shift+S | Starta/starta om run |

#### Navigering {#navigation-1}

| Genväg | Åtgärd |
|----------|--------|
| Ctrl+1-9 | Byt workstream (från valfri vy) |
| ⌘Shift+O | Öppna i extern browser |
| ⌘Shift+E | Öppna i extern terminal |

---

## Konfiguration {#configuration}

Hur man automatiserar de tråkiga delarna.

### Script och livscykel {#scripts--lifecycle}

Lägg en `.factoryfloor.json` i projektets rotkatalog för att automatisera workstream-livscykeln.

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | När det körs |
|------|-------------|
| `setup` | En gång, när en workstream skapas. Installera beroenden, kör migreringar, vad som helst. |
| `run` | På begäran via Environment-tabben (⌘E). Kapslad i `ff-run` för port detection. |
| `teardown` | När en workstream arkiveras eller rensas. Stoppa containrar, städa upp. |

Alla fält är valfria. Script körs i workstream-katalogen med ditt login shell. Ja, även [fish](https://github.com/alltuner/factoryfloor/pull/324). Fråga inte hur lång tid det tog.

Factory Floor läser också `conductor.json` och `.superset/config.json` om `.factoryfloor.json` inte finns. För kompatibilitet är artigt. (Dags för en [standard](https://xkcd.com/927/)?)

#### Environment-tabben {#the-environment-tab}

Delad layout: **Setup** till vänster, **Run** till höger.

- **Ctrl+Shift+R** — bygg om (kör om setup)
- **Ctrl+Shift+S** — starta/starta om run-scriptet

### Miljövariabler {#environment-variables}

Varje terminal, setup-script och run-kommando i en workstream har dessa variabler:

| Variabel | Vad det är | Exempel |
|----------|-----------|---------|
| `FF_PROJECT` | Projektnamn | `my-app` |
| `FF_WORKSTREAM` | Workstream-namn | `coral-tidal-reef` |
| `FF_PROJECT_DIR` | Huvudrepots sökväg | `/Users/you/my-app` |
| `FF_WORKTREE_DIR` | Worktree-sökväg | `~/.factoryfloor/worktrees/my-app/coral-tidal-reef` |
| `FF_PORT` | Deterministisk port (40001-49999) | `42847` |

#### Om FF_PORT {#about-ff_port}

Varje workstream får en deterministisk port baserad på en hash av worktree-sökvägen. Samma workstream, samma port, varje gång. Inga portkonflikter mellan workstreams. Använd den i ditt run-script: `PORT=$FF_PORT npm run dev`. Om du kör tusentals workstreams samtidigt kanske du får en kollision 🎲 men förhoppningsvis tar minnet slut först.

#### .env symlink {#env-symlink}

När aktiverat (Settings > General) skapar Factory Floor symlinks för `.env` och `.env.local` från ditt huvudrepo till varje worktree. Så dina hemligheter följer med utan kopiera-klistra. På tal om hemligheter, har vi berättat om [Vaultuner](https://vaultuner.alltuner.com)?

### Inställningar {#settings}

Öppna med **⌘,** eller klicka på kugghjulsikonen.

#### Allmänt {#general}

- **Base directory** — standardplats för nya projekt
- **Branch prefix** — prefix för workstream-branches (standard: `ff`)
- **Symlink .env files** — auto-symlink `.env` och `.env.local` till worktrees
- **Theme** — System, Ljust eller Mörkt
- **Language** — Systemstandard, English, Catalan, Spanish eller Swedish
- **Confirm before quitting** — frågar innan stängning med aktiva workstreams
- **Launch at login** — startar Factory Floor vid uppstart

#### Coding Agent {#coding-agent}

- **Bypass permission prompts** — inaktiverar bekräftelse för agent-åtgärder
- **Agent Teams** — experimentellt multi-agent-läge
- **Auto-rename branch** — agenten byter namn på branch vid första prompten
- **Tmux mode** — sessionspersistens via tmux

#### Appar {#apps}

- **External Terminal** — vilken terminal-app som öppnas med ⌘Shift+E
- **External Browser** — vilken browser för ⌘Shift+O och ⌘Click

#### Avancerat {#advanced}

- **Usage analytics** — integritetsvänlig telemetry (bara appversion, OS, locale)
- **Crash reports** — Sentry-baserad crash reporting
- **Detailed logging** — loggar script-utdata för felsökning
- **Quick action debug mode** — visar rå utdata från quick actions
- **Bleeding edge updates** — välj att ta emot förhandsversioner
- **Clear project list** — kärnvapenalternativet, tar bort alla projekt från sidebar

---

## Integrationer {#integrations}

Koppla Factory Floor till allt annat.

### CLI {#cli}

Installera `ff`-kommandot från Settings > Environment > Install CLI. Sedan:

```
ff /path/to/your/project
```

Öppnar katalogen i Factory Floor. Det är allt det gör, och det är allt det behöver göra.

### GitHub {#github}

Kräver [gh CLI](https://cli.github.com/) med autentisering (`gh auth login`).

- **Projektvy** — repo-info, beskrivning, stjärnor, forks, öppna issues, senaste PRs
- **Workstream sidebar** — PR-nummer, titel och status (open/merged/closed) per branch
- **Merge-detection** — visar "Purge" badge när en branchs PR är mergad

#### Quick actions {#quick-actions-1}

Från sidebar, kör ett-klicks-operationer: **Create PR** (AI-genererad titel och beskrivning), **Push** (till origin med `-u`), eller **Abandon PR** (stänger med en kommentar). För om du är trött på att skriva "now commit, push, and open a PR" till Claude för hundrade gången, är du inte ensam.

### Uppdateringar {#updates}

Factory Floor visar en badge i sidebar när en nyare version finns tillgänglig. Du kan också kontrollera manuellt från **Factory Floor > Check for Updates...**

**Homebrew-användare:**

```
brew upgrade factory-floor
```

**DMG-användare:** uppdateringar hanteras automatiskt via [Sparkle](https://sparkle-project.org). Kontrollera manuellt från menyn: **Factory Floor > Check for Updates...**

Aktivera **Bleeding edge updates** i Settings > Advanced för förhandsversioner. För dig som gillar att leva på kanten och skicka buggrapporter.

---

## Enterprise-funktioner 😉 {#enterprise-features-}

### Kodredigerare {#code-editor}

Nä. Ingen syntaxmarkering, ingen autocomplete, ingen minimap. Våra obefintliga riskkapitalister har inte drivit någon företagsagenda. Vi tänker att du ska använda verktygen du redan älskar: [Zed](https://zed.dev), [VS Code](https://code.visualstudio.com), vad som helst. Factory Floor ger dig en coding agent, en browser och en worktree. Dessutom, vem skriver kod längre?

### Merge-visare {#merge-viewer}

Också nä. Din git-klient gör redan detta bättre än vi någonsin skulle kunna. Vi ser bara till att varje workstream har en ren branch redo för granskning. Du håller väl dina PRs små och undviker merge-konflikter, va? ...Va?

---

## Felsökning {#troubleshooting}

#### "Tools not found" {#tools-not-found}

Factory Floor upptäcker verktyg från ditt login shell. Om `claude`, `gh`, `git` eller `tmux` inte dyker upp:

- Se till att de finns i din shells PATH
- Fish 4.0- och Nix-användare: appen hanterar dessa miljöer, men om något är fel, kolla Settings > Environment

#### Tmux-sessioner som inte persisterar {#tmux-sessions-not-persisting}

- Verifiera att tmux är installerat och upptäckt (Settings > Environment)
- Factory Floor använder sin egen tmux socket (`-L factoryfloor`), så din personliga tmux-konfiguration stör inte

#### Port inte upptäckt {#port-not-detected}

- Se till att ditt run-script använder `$FF_PORT` (eller att porten upptäcks från processträdet)
- `ff-run`-launchern kapslar run-scriptet, den övervakar barnprocesser efter lyssnande TCP-portar
- Kolla Settings > Advanced > Detailed logging för debug-utdata

#### Något annat som inte fungerar? {#something-else-broken}

- [Rapportera en bugg](https://github.com/alltuner/factoryfloor/issues/new?template=bug_report.yml) — berätta vad som gick fel
- [Skicka en fix-prompt](https://github.com/alltuner/factoryfloor/issues/new?template=fix_prompt.yml) — skriv prompten, vi låter agenten ta sig an det
- [Något annat](https://github.com/alltuner/factoryfloor/issues/new) — idéer, frågor, existentiella tvivel
