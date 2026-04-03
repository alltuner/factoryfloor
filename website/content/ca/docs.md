---
title: Docs
translationKey: docs
hideInstall: true
layout: docs
---

## Primeres passes {#getting-started}

Estem al 2026. Construïm sobre tmux (2007), git worktrees (2015), terminals (1978, l'era del VT100, quan fins i tot en [David](https://davidpoblador.com) era només un projecte de futur), i renderitzat per GPU (gràcies [Mitchell](https://mitchellh.com) per [Ghostty](https://ghostty.org)). Eines velles, trucs nous.

Necessites dues coses: un Mac i la vaga sensació que el teu flux de treball podria ser millor.

```
brew install --cask factory-floor
```

<a href="https://github.com/alltuner/factoryfloor/releases/latest/download/FactoryFloor.dmg" class="docs-download"><svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download DMG</a>

Factory Floor funciona millor quan tens instal·lat el següent (t'avisarà si falta alguna cosa):

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — la raó de ser, bàsicament
- **git** — probablement ja el tens
- **[gh](https://cli.github.com/)** — GitHub CLI, per a l'estat de PRs i quick actions
- **[tmux](https://github.com/tmux/tmux)** — opcional, permet persistència de sessions

#### Els teus primers 30 segons {#your-first-30-seconds}

1. Obre Factory Floor
2. Arrossega un repositori git cap al sidebar (o fes clic a **+** per triar-ne un)
3. Prem **⌘N** per crear un workstream
4. Ja està. Ja estàs programant amb IA.

No cal cap fitxer de configuració. Factory Floor detecta automàticament la teva configuració de git, les eines instal·lades i les connexions amb GitHub.

---

## Conceptes clau {#core-concepts}

Les tres coses amb les quals interactuaràs cada dia.

### Projectes {#projects}

Un projecte és un repositori git. Arrossega un directori al sidebar o fes clic al botó **+**. Factory Floor comprova si és un repositori git (i t'ofereix inicialitzar-ne un si no ho és).

La vista general del projecte mostra informació del repositori, detalls de GitHub (estrelles, forks, issues obertes), fins a 5 PRs recents, i documentació markdown detectada automàticament del teu repositori.

Els projectes s'ordenen per **Recent** (última activitat) per defecte. Canvia a **A-Z** si ets d'aquest tipus de persona.

Fes clic dret sobre un projecte al sidebar per accés ràpid: **Reveal in Finder**, **Open in External Terminal**, **Open on GitHub**, o **Remove** (els fitxers es queden al disc, no som monstres).

### Workstreams {#workstreams}

Un workstream és on passa la feina. Cadascun té el seu propi git worktree, branch, terminal, coding agent, i navegador. Estan completament aïllats entre si.

**⌘N** crea un workstream nou. Entre bastidors:

1. Descarrega l'última branch per defecte des de l'origin
2. Crea un git worktree amb una branch nova (amb el prefix de branch configurat, per defecte: `ff`)
3. Fa symlink de `.env` i `.env.local` des del repositori principal (si està activat)
4. Executa el setup script (si està configurat)
5. Llança el coding agent

La interfície apareix a l'instant, la creació del worktree passa en segon pla.

#### Workstream tabs {#workstream-tabs}

- **Info** (⌘I) — nom de branch, estat de PR, documentació del projecte
- **Agent** (⌘Return) — la teva sessió de Claude Code
- **Environment** (⌘E) — controls de setup i run script
- **Terminal** (⌘T) — terminal tabs addicionals, tants com vulguis
- **Navegador** (⌘B) — navegador integrat amb detecció automàtica de port

#### Branch auto-rename {#branch-auto-rename}

Amb **Auto-rename branch** activat a la configuració, el coding agent canvia el nom de la teva branch per coincidir amb la tasca al primer prompt. Així `ff/coral-tidal-reef` es converteix en `ff/fix-login-timeout`.

#### Eliminar vs. purgar {#removing-vs-purging}

- **Remove** — mata terminals i agent, però el worktree es queda al disc
- **Purge** — elimina permanentment el worktree i la branch (demana confirmació si hi ha canvis sense commit)

Quan un PR es fusiona, Factory Floor mostra un badge "Purge" perquè sàpigues que pots netejar tranquil·lament.

### El Coding Agent {#the-coding-agent}

El Coding Agent tab executa [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) en un terminal integrat. Es situa just després del tab Info a cada workstream.

#### Configuració de l'agent {#agent-settings}

- **Bypass permission prompts** — salta els diàlegs de confirmació. Útil si confies en el teu agent (i vius perillosament).
- **Tmux mode** — embolcalla les sessions de l'agent en tmux perquè sobrevisquin als reinicis de l'app. Requereix tmux.
- **Auto-rename branch** — permet que l'agent canviï el nom de la branch per coincidir amb la tasca.
- **Agent Teams** — coordinació multi-agent experimental, cortesia de Claude Code. Confiem en Anthropic, oi?

#### Quick actions {#quick-actions}

Les quick actions executen tasques puntuals de Claude des del sidebar:

- **Commit** — prepara i fa commit amb un missatge generat per IA
- **Push** — fa push de la branch actual a l'origin
- **Create PR** — crea una pull request amb títol i descripció generats per IA
- **Abandon PR** — tanca la PR

S'executen com a crides `claude -p` en segon pla. Activa **Quick action debug mode** a la configuració si vols saber com es fa l'embotit. Confia en nosaltres, en [David](https://davidpoblador.com) va passar més temps del que pot admetre depurant comportaments estranys allà dins.

---

## El teu espai de treball {#your-workspace}

Terminals, navegadors, i dreceres, les eines dins de cada workstream.

### Terminals {#terminals}

Els terminals es renderitzen per GPU via [Ghostty](https://ghostty.org). Són ràpids.

- **⌘T** — nou terminal tab
- **⌘W** — tanca tab (o Ctrl+D per sortir del shell)
- **⌘1-9** — canvia entre tabs
- **⌘Shift+[** / **⌘Shift+]** — cicla entre tabs

Pots arrossegar fitxers i text sobre el terminal. Perquè de vegades el ratolí està bé, la veritat.

**⌘Shift+E** obre el directori del workstream a la teva aplicació de terminal externa preferida.

### El navegador {#the-browser}

Cada workstream pot tenir pestanyes de navegador (⌘B). El navegador és integrat, no cal canviar de finestra.

#### Port detection {#port-detection}

Quan el teu run script inicia un servidor de desenvolupament, Factory Floor detecta automàticament el port en escolta i hi navega el navegador. No cal configurar res. El llançador `ff-run` monitoritza l'arbre de processos per trobar listeners TCP.

#### Navegació {#navigation}

- **⌘L** — focus a la barra d'adreces
- **⌘Shift+O** — obre la URL actual al teu navegador extern
- **⌘Click** — obre els enllaços al teu navegador extern

El navegador mostra una pàgina d'error de connexió amb un botó de reintentar si el servidor encara no està llest. Navegarà automàticament quan es detecti el port.

### Dreceres de teclat {#keyboard-shortcuts}

Factory Floor prioritza el teclat. Aquí tens tot.

#### Global {#global}

| Drecera | Acció |
|----------|--------|
| ⌘N | Nou workstream (o projecte, si no n'hi ha cap) |
| ⌘Shift+N | Nou projecte |
| ⌘, | Configuració |
| ⌘/ | Ajuda |

#### Workstream {#workstream}

| Drecera | Acció |
|----------|--------|
| ⌘Return | Focus Coding Agent |
| ⌘I | Panell Info |
| ⌘E | Environment |
| ⌘T | Nou Terminal |
| ⌘B | Nou navegador |
| ⌘W | Tanca tab |
| ⌘L | Barra d'adreces (navegador) |
| ⌘0 | Torna al projecte |
| ⌘1-9 | Canvia de tab |
| ⌘Shift+[ | Tab anterior |
| ⌘Shift+] | Tab següent |
| Ctrl+Shift+R | Reconstrueix setup |
| Ctrl+Shift+S | Inicia/reinicia run |

#### Navegació {#navigation-1}

| Drecera | Acció |
|----------|--------|
| Ctrl+1-9 | Canvia de workstream (des de qualsevol vista) |
| ⌘Shift+O | Obre al navegador extern |
| ⌘Shift+E | Obre al terminal extern |

---

## Configuració {#configuration}

Com automatitzar les parts avorrides.

### Scripts i cicle de vida {#scripts--lifecycle}

Posa un `.factoryfloor.json` a l'arrel del teu projecte per automatitzar el cicle de vida dels workstreams.

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | Quan s'executa |
|------|-------------|
| `setup` | Un cop, quan es crea un workstream. Instal·la dependències, executa migracions, el que sigui. |
| `run` | Sota demanda des del tab Environment (⌘E). Embolcallat amb `ff-run` per a port detection. |
| `teardown` | Quan un workstream s'arxiva o es purga. Atura contenidors, neteja. |

Tots els camps són opcionals. Els scripts s'executen al directori del workstream usant el teu shell de login. Sí, fins i tot [fish](https://github.com/alltuner/factoryfloor/pull/324). No preguntis quant de temps va costar.

Factory Floor també llegeix `conductor.json` i `.superset/config.json` si `.factoryfloor.json` no existeix. Perquè la compatibilitat és de bona educació. (Hora d'un [estàndard](https://xkcd.com/927/)?)

#### El tab Environment {#the-environment-tab}

Disposició en panell dividit: **Setup** a l'esquerra, **Run** a la dreta.

- **Ctrl+Shift+R** — reconstrueix (reexecuta setup)
- **Ctrl+Shift+S** — inicia/reinicia el run script

### Variables d'entorn {#environment-variables}

Cada terminal, setup script, i comanda run d'un workstream té aquestes variables:

| Variable | Què és | Exemple |
|----------|-----------|---------|
| `FF_PROJECT` | Nom del projecte | `my-app` |
| `FF_WORKSTREAM` | Nom del workstream | `coral-tidal-reef` |
| `FF_PROJECT_DIR` | Ruta del repositori principal | `/Users/you/my-app` |
| `FF_WORKTREE_DIR` | Ruta del worktree | `~/.factoryfloor/worktrees/my-app/coral-tidal-reef` |
| `FF_PORT` | Port determinista (40001-49999) | `42847` |

#### Sobre FF_PORT {#about-ff_port}

Cada workstream obté un port determinista basat en un hash de la ruta del worktree. Mateix workstream, mateix port, sempre. Sense conflictes de port entre workstreams. Usa'l al teu run script: `PORT=$FF_PORT npm run dev`. Si el teu rotllo és executar milers de workstreams simultàniament, potser et trobes una col·lisió 🎲 però amb sort et quedes sense memòria abans.

#### .env symlink {#env-symlink}

Quan està activat (Settings > General), Factory Floor fa symlink de `.env` i `.env.local` des del teu repositori principal a cada worktree. Així els teus secrets et segueixen sense haver de copiar i enganxar. Parlant de secrets, t'hem parlat de [Vaultuner](https://vaultuner.alltuner.com)?

### Configuració {#settings}

Obre amb **⌘,** o fes clic a la icona d'engranatge.

#### General {#general}

- **Base directory** — ubicació per defecte per a nous projectes
- **Branch prefix** — prefix per a les branches dels workstreams (per defecte: `ff`)
- **Symlink .env files** — symlink automàtic de `.env` i `.env.local` als worktrees
- **Theme** — Sistema, Clar, o Fosc
- **Language** — Per defecte del sistema, anglès, català, castellà o suec
- **Confirm before quitting** — pregunta abans de tancar amb workstreams actius
- **Launch at login** — inicia Factory Floor en arrencar

#### Coding Agent {#coding-agent}

- **Bypass permission prompts** — desactiva la confirmació per accions de l'agent
- **Agent Teams** — mode multi-agent experimental
- **Auto-rename branch** — l'agent canvia el nom de la branch al primer prompt
- **Tmux mode** — persistència de sessions via tmux

#### Apps {#apps}

- **External Terminal** — quina aplicació de terminal obrir amb ⌘Shift+E
- **External Browser** — quin navegador per a ⌘Shift+O i ⌘Click

#### Avançat {#advanced}

- **Usage analytics** — telemetry respectuosa amb la privacitat (només versió de l'app, SO, i locale)
- **Crash reports** — informes d'errors basats en Sentry
- **Detailed logging** — registra la sortida dels scripts per a depuració
- **Quick action debug mode** — mostra la sortida en brut de les quick actions
- **Bleeding edge updates** — opta per builds de pre-llançament
- **Clear project list** — opció nuclear, elimina tots els projectes del sidebar

---

## Integracions {#integrations}

Connectant Factory Floor amb tot el demés.

### CLI {#cli}

Instal·la la comanda `ff` des de Settings > Environment > Install CLI. Després:

```
ff /path/to/your/project
```

Obre el directori a Factory Floor. Això és tot el que fa, i és tot el que necessita fer.

### GitHub {#github}

Requereix el [gh CLI](https://cli.github.com/) amb autenticació (`gh auth login`).

- **Vista de projecte** — info del repositori, descripció, estrelles, forks, issues obertes, PRs recents
- **Workstream sidebar** — número de PR, títol, i estat (obert/fusionat/tancat) per branch
- **Detecció de merge** — mostra el badge "Purge" quan la PR d'una branch s'ha fusionat

#### Quick actions {#quick-actions-1}

Des del sidebar, executa operacions d'un sol clic: **Create PR** (títol i descripció generats per IA), **Push** (a l'origin amb `-u`), o **Abandon PR** (tanca amb un comentari). Perquè si estàs cansat d'escriure "ara fes commit, push, i obre una PR" a Claude per centèsima vegada, no ets l'únic.

### Actualitzacions {#updates}

Factory Floor mostra un badge al sidebar quan hi ha una versió més nova disponible. També pots comprovar-ho manualment des de **Factory Floor > Check for Updates...**

**Usuaris de Homebrew:**

```
brew upgrade factory-floor
```

**Usuaris de DMG:** les actualitzacions es gestionen automàticament via [Sparkle](https://sparkle-project.org). Comprova manualment des del menú: **Factory Floor > Check for Updates...**

Activa **Bleeding edge updates** a Settings > Advanced per a builds de pre-llançament. Per als que els agrada viure al límit i enviar informes d'errors.

---

## Funcionalitats Enterprise 😉 {#enterprise-features-}

### Editor de codi {#code-editor}

No. Sense ressaltat de sintaxi, sense autocompletar, sense minimapa. Els nostres VCs inexistents no han estat imposant cap agenda corporativa. La intenció és que facis servir les eines que ja t'agraden: [Zed](https://zed.dev), [VS Code](https://code.visualstudio.com), el que sigui. Factory Floor et dóna un coding agent, un navegador, i un worktree. A més, qui escriu codi avui en dia?

### Visor de merge {#merge-viewer}

Tampoc. El teu client de git ja ho fa millor del que nosaltres mai podríem. Nosaltres només ens assegurem que cada workstream tingui una branch neta llesta per a revisió. Estàs mantenint les teves PRs petites i evitant conflictes de merge, oi? ...Oi?

---

## Resolució de problemes {#troubleshooting}

#### "Tools not found" {#tools-not-found}

Factory Floor detecta les eines des del teu shell de login. Si `claude`, `gh`, `git`, o `tmux` no apareixen:

- Assegura't que estan al PATH del teu shell
- Usuaris de Fish 4.0 i Nix: l'app gestiona aquests entorns, però si alguna cosa no va bé, comprova Settings > Environment

#### Les sessions de tmux no persisteixen {#tmux-sessions-not-persisting}

- Verifica que tmux està instal·lat i detectat (Settings > Environment)
- Factory Floor utilitza el seu propi socket de tmux (`-L factoryfloor`), així que la teva configuració personal de tmux no interferirà

#### Port no detectat {#port-not-detected}

- Assegura't que el teu run script utilitza `$FF_PORT` (o que el port es detecta des de l'arbre de processos)
- El llançador `ff-run` embolcalla el run script, monitoritza els processos fills per trobar listeners TCP
- Comprova Settings > Advanced > Detailed logging per a sortida de depuració

#### Alguna altra cosa no funciona? {#something-else-broken}

- [Informa'ns d'un error](https://github.com/alltuner/factoryfloor/issues/new?template=bug_report.yml) — explica'ns què ha anat malament
- [Envia un fix prompt](https://github.com/alltuner/factoryfloor/issues/new?template=fix_prompt.yml) — escriu el prompt, deixarem que l'agent ho intenti
- [Alguna altra cosa](https://github.com/alltuner/factoryfloor/issues/new) — idees, preguntes, dubtes existencials
