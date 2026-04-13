---
title: Docs
translationKey: docs
hideInstall: true
layout: docs
---

## Erste Schritte {#getting-started}

Wir schreiben 2026. Wir bauen auf tmux (2007), Git-Worktrees (2015), Terminals (1978, die VT100-Ära, als selbst [David](https://davidpoblador.com) nur ein Zukunftsprojekt war) und GPU-Rendering (danke [Mitchell](https://mitchellh.com) für [Ghostty](https://ghostty.org)). Alte Werkzeuge, neue Tricks.

Du brauchst zwei Dinge: einen Mac und das vage Gefühl, dass dein aktueller Workflow besser sein könnte.

```
brew install --cask factory-floor
```

<a href="https://github.com/alltuner/factoryfloor/releases/latest/download/FactoryFloor.dmg" class="docs-download"><svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> DMG herunterladen</a>

Factory Floor funktioniert am besten, wenn diese Tools installiert sind (die App sagt dir, wenn etwas fehlt):

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — der eigentliche Sinn der Sache
- **git** — hast du wahrscheinlich schon
- **[gh](https://cli.github.com/)** — GitHub CLI, für PR-Status und Schnellaktionen
- **[tmux](https://github.com/tmux/tmux)** — optional, ermöglicht Sitzungspersistenz

#### Deine ersten 30 Sekunden {#your-first-30-seconds}

1. Öffne Factory Floor
2. Ziehe ein Git-Repository auf die Seitenleiste (oder klicke **+**, um eines auszuwählen)
3. Drücke **⌘N**, um einen Workstream zu erstellen
4. Das war's. Du programmierst jetzt mit KI.

Keine Konfigurationsdateien nötig. Factory Floor erkennt dein Git-Setup, installierte Tools und GitHub-Verbindungen automatisch.

---

## Grundkonzepte {#core-concepts}

Die drei Dinge, mit denen du jeden Tag arbeitest.

### Projekte {#projects}

Ein Projekt ist ein Git-Repository. Ziehe ein Verzeichnis auf die Seitenleiste oder klicke den **+**-Button. Factory Floor prüft, ob es ein Git-Repo ist (und bietet an, eines zu initialisieren, wenn nicht).

Die Projektübersicht zeigt Repository-Infos, GitHub-Details (Sterne, Forks, offene Issues), bis zu 5 aktuelle PRs und automatisch erkannte Markdown-Dokumentation aus deinem Repo.

Projekte werden standardmäßig nach **Zuletzt** (letzte Aktivität) sortiert. Wechsle zu **A-Z**, wenn du so einer bist.

Rechtsklicke auf ein Projekt in der Seitenleiste für Schnellzugriff: **Im Finder anzeigen**, **In externem Terminal öffnen**, **Auf GitHub öffnen** oder **Entfernen** (Dateien bleiben auf der Festplatte, wir sind keine Ungeheuer).

### Workstreams {#workstreams}

Ein Workstream ist, wo die Arbeit stattfindet. Jeder bekommt seinen eigenen Git-Worktree, Branch, Terminal, Coding-Agent und Browser-Tab. Sie sind vollständig voneinander isoliert.

**⌘N** erstellt einen neuen Workstream. Hinter den Kulissen:

1. Holt den neuesten Default-Branch von Origin
2. Erstellt einen Git-Worktree mit einem frischen Branch (mit deinem Branch-Präfix, Standard: `ff`)
3. Verknüpft `.env` und `.env.local` aus dem Hauptrepo (wenn aktiviert)
4. Führt das Setup-Skript aus (wenn konfiguriert)
5. Startet den Coding-Agent

Die Oberfläche erscheint sofort — die Worktree-Erstellung läuft im Hintergrund.

#### Workstream-Tabs {#workstream-tabs}

- **Info** — Branch-Name, PR-Status, Projektdokumentation
- **Agent** (⌘Return) — deine Claude-Code-Sitzung
- **Environment** — Setup- und Run-Skript-Steuerungen
- **Terminal** (⌘T) — zusätzliche Terminal-Tabs, so viele du willst
- **Browser** (⌘B) — integrierter Browser mit automatischer Port-Erkennung

#### Branch Auto-Rename {#branch-auto-rename}

Mit aktiviertem **Auto-rename branch** in den Einstellungen benennt der Coding-Agent deinen Branch beim ersten Prompt passend zur Aufgabe um. So wird `ff/coral-tidal-reef` zu `ff/fix-login-timeout`.

#### Entfernen vs. Bereinigen {#removing-vs-purging}

- **Remove** — beendet Terminals und Agent, aber der Worktree bleibt auf der Festplatte
- **Purge** — löscht Worktree und Branch dauerhaft (fragt nach Bestätigung bei nicht committeten Änderungen)

Wenn ein PR gemergt wurde, zeigt Factory Floor ein „Purge"-Badge, damit du weißt, dass du sicher aufräumen kannst.

### Der Coding-Agent {#the-coding-agent}

Der Coding-Agent-Tab führt [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) in einem integrierten Terminal aus. Er sitzt direkt nach dem Info-Tab in jedem Workstream.

#### Agent-Einstellungen {#agent-settings}

- **Bypass permission prompts** — überspringt Bestätigungsdialoge. Nützlich, wenn du deinem Agenten vertraust (und gerne gefährlich lebst).
- **Tmux mode** — kapselt Agent-Sitzungen in tmux, damit sie App-Neustarts überleben. Erfordert tmux.
- **Auto-rename branch** — lässt den Agenten den Branch passend zur Aufgabe umbenennen.
- **Agent Teams** — experimentelle Multi-Agent-Koordination, mit freundlicher Unterstützung von Claude Code. Wir vertrauen Anthropic, oder?

#### Schnellaktionen {#quick-actions}

Schnellaktionen führen einmalige Claude-Aufgaben aus der Seitenleiste aus:

- **Commit** — staged und committet mit einer KI-generierten Nachricht
- **Push** — pusht den aktuellen Branch zu Origin
- **Create PR** — erstellt einen Pull Request mit KI-generiertem Titel und Beschreibung
- **Close PR** — schließt den PR

Diese laufen als Hintergrund-`claude -p`-Aufrufe. Aktiviere **Quick action debug mode** in den Einstellungen, wenn du wissen willst, wie die Wurst gemacht wird. Vertrau uns, [David](https://davidpoblador.com) hat mehr Zeit als er zugeben will damit verbracht, seltsame Verhaltensweisen dort drin zu debuggen.

---

## Dein Arbeitsbereich {#your-workspace}

Terminals, Browser und Tastaturkürzel — die Werkzeuge in jedem Workstream.

### Terminals {#terminals}

Terminals werden GPU-gerendert über [Ghostty](https://ghostty.org). Sie sind schnell.

- **⌘T** — neuer Terminal-Tab
- **⌘W** — Tab schließen (oder Ctrl+D zum Beenden der Shell)
- **⌘1-9** — zwischen Tabs wechseln
- **⌘Shift+[** / **⌘Shift+]** — durch Tabs blättern

Du kannst Dateien und Text auf das Terminal ziehen. Weil manchmal die Maus völlig in Ordnung ist, ehrlich.

**⌘Shift+E** öffnet das Workstream-Verzeichnis in deiner bevorzugten externen Terminal-App.

### Der Browser {#the-browser}

Jeder Workstream kann Browser-Tabs haben (⌘B). Der Browser ist integriert — kein Fensterwechsel nötig.

#### Port-Erkennung {#port-detection}

Wenn dein Run-Skript einen Dev-Server startet, erkennt Factory Floor den lauschenden Port automatisch und navigiert den Browser dorthin. Keine Konfiguration nötig. Der `ff-run`-Launcher überwacht den Prozessbaum nach TCP-Listenern.

#### Navigation {#navigation}

- **⌘L** — Adressleiste fokussieren
- **⌘Shift+O** — aktuelle URL in externem Browser öffnen
- **⌘Click** — öffnet Links in deinem externen Browser

Der Browser zeigt eine Verbindungsfehler-Seite mit einem Retry-Button, wenn der Server noch nicht bereit ist. Er navigiert automatisch, sobald der Port erkannt wird.

### Tastaturkürzel {#keyboard-shortcuts}

Factory Floor ist tastaturorientiert. Hier ist alles.

#### Global {#global}

| Kürzel | Aktion |
|----------|--------|
| ⌘N | Neuer Workstream (oder Projekt, wenn keines existiert) |
| ⌘Shift+N | Neues Projekt |
| ⌘, | Einstellungen |
| ⌘/ | Hilfe |
| ⌘Option+S | Seitenleiste ein-/ausblenden |

#### Workstream {#workstream}

| Kürzel | Aktion |
|----------|--------|
| ⌘1-9 | Tab wechseln |
| ⌘Shift+[ | Vorheriger Tab |
| ⌘Shift+] | Nächster Tab |
| ⌘Return | Coding-Agent fokussieren |
| ⌘T | Neues Terminal |
| ⌘B | Neuer Browser |
| ⌘W | Tab schließen |
| ⌘Shift+W | Workstream archivieren |
| ⌘L | Adressleiste (Browser) |
| ⌘Shift+Return | Starten/Neustart |

#### Navigation {#navigation-1}

| Kürzel | Aktion |
|----------|--------|
| ⌘[ | Vorheriger Workstream |
| ⌘] | Nächster Workstream |
| ⌘↑ | Vorheriges Projekt |
| ⌘↓ | Nächstes Projekt |
| ⌘0 | Zurück zum Projekt |
| ⌘Option+B | In externem Browser öffnen |
| ⌘Option+T | In externem Terminal öffnen |

---

## Konfiguration {#configuration}

So automatisierst du die langweiligen Teile.

### Skripte und Lebenszyklus {#scripts--lifecycle}

Lege eine `.factoryfloor.json` in dein Projektstammverzeichnis, um den Workstream-Lebenszyklus zu automatisieren.

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | Wann es läuft |
|------|-------------|
| `setup` | Einmal, wenn ein Workstream erstellt wird. Abhängigkeiten installieren, Migrationen ausführen, was auch immer. |
| `run` | Auf Abruf über den Environment-Tab. Eingebettet in `ff-run` für Port-Erkennung. |
| `teardown` | Wenn ein Workstream archiviert oder bereinigt wird. Container stoppen, aufräumen. |

Alle Felder sind optional. Skripte laufen im Workstream-Verzeichnis mit deiner Login-Shell. Ja, sogar [fish](https://github.com/alltuner/factoryfloor/pull/324). Frag nicht, wie lange das gedauert hat.

Factory Floor liest auch `.emdash.json`, `conductor.json` und `.superset/config.json`, wenn `.factoryfloor.json` nicht existiert. Weil Kompatibilität höflich ist. (Zeit für einen [Standard](https://xkcd.com/927/)?) Bei Fallback-Konfiguration injiziert Factory Floor kompatible Umgebungsvariablen, damit Skripte ohne Änderung funktionieren (z.B. `CONDUCTOR_PORT`, `EMDASH_PORT`, `SUPERSET_PORT_BASE`).

#### Der Environment-Tab {#the-environment-tab}

Geteiltes Layout: **Setup** links, **Run** rechts.

- **⌘Shift+Return** — Run-Skript starten/neustarten

### Umgebungsvariablen {#environment-variables}

Jedes Terminal, Setup-Skript und Run-Kommando in einem Workstream hat diese Variablen:

| Variable | Was es ist | Beispiel |
|----------|-----------|---------|
| `FF_PROJECT` | Projektname | `my-app` |
| `FF_WORKSTREAM` | Workstream-Name | `coral-tidal-reef` |
| `FF_PROJECT_DIR` | Hauptrepository-Pfad | `/Users/you/my-app` |
| `FF_WORKTREE_DIR` | Worktree-Pfad | `~/.factoryfloor/worktrees/my-app/coral-tidal-reef` |
| `FF_PORT` | Deterministischer Port (40001-49999) | `42847` |
| `FF_DEFAULT_BRANCH` | Standard-Branch (main, master, etc.) | `main` |

#### Über FF_PORT {#about-ff_port}

Jeder Workstream bekommt einen deterministischen Port basierend auf einem Hash des Worktree-Pfads. Gleicher Workstream, gleicher Port, jedes Mal. Keine Port-Konflikte zwischen Workstreams. Verwende ihn in deinem Run-Skript: `PORT=$FF_PORT npm run dev`. Falls du tausende Workstreams gleichzeitig laufen lässt, bekommst du vielleicht eine Kollision 🎲, aber hoffentlich geht dir vorher der Speicher aus.

#### .env-Symlink {#env-symlink}

Wenn aktiviert (Settings > General), erstellt Factory Floor Symlinks für `.env` und `.env.local` aus deinem Hauptrepo in jeden Worktree. So folgen dir deine Geheimnisse ohne Kopieren und Einfügen. Apropos Geheimnisse, haben wir dir schon von [Vaultuner](https://vaultuner.alltuner.com) erzählt?

### Einstellungen {#settings}

Öffne mit **⌘,** oder klicke auf das Zahnrad-Symbol.

#### Allgemein {#general}

- **Base directory** — Standardort für neue Projekte
- **Branch prefix** — Präfix für Workstream-Branches (Standard: `ff`)
- **Symlink .env files** — automatische Verknüpfung von `.env` und `.env.local` in Worktrees
- **Theme** — System, Hell oder Dunkel
- **Language** — Systemstandard, Englisch, Katalanisch, Spanisch, Schwedisch oder Deutsch
- **Confirm before quitting** — fragt vor dem Beenden bei aktiven Workstreams
- **Launch at login** — startet Factory Floor beim Anmelden

#### Coding-Agent {#coding-agent}

- **Bypass permission prompts** — deaktiviert Bestätigungen für Agent-Aktionen
- **Agent Teams** — experimenteller Multi-Agent-Modus
- **Auto-rename branch** — Agent benennt Branch beim ersten Prompt um
- **Tmux mode** — Sitzungspersistenz über tmux

#### Apps {#apps}

- **External Terminal** — welche Terminal-App mit ⌘Shift+E geöffnet wird
- **External Browser** — welcher Browser für ⌘Shift+O und ⌘Click

#### Erweitert {#advanced}

- **Usage analytics** — datenschutzfreundliche Telemetrie (nur App-Version, OS, Sprache)
- **Crash reports** — Sentry-basierte Absturzberichte
- **Detailed logging** — protokolliert Skript-Ausgaben zur Fehlersuche
- **Quick action debug mode** — zeigt Rohausgaben der Schnellaktionen
- **Bleeding edge updates** — Vorabversionen erhalten
- **Clear project list** — Atomoption, entfernt alle Projekte aus der Seitenleiste

---

## Integrationen {#integrations}

Factory Floor mit allem anderen verbinden.

### CLI {#cli}

Installiere den `ff`-Befehl über Settings > Environment > Install CLI. Dann:

```
ff /path/to/your/project
```

Öffnet das Verzeichnis in Factory Floor. Das ist alles, was er tut, und das ist alles, was er tun muss.

### GitHub {#github}

Erfordert die [gh CLI](https://cli.github.com/) mit Authentifizierung (`gh auth login`).

- **Projektansicht** — Repo-Infos, Beschreibung, Sterne, Forks, offene Issues, aktuelle PRs
- **Workstream-Seitenleiste** — PR-Nummer, Titel und Status (open/merged/closed) pro Branch
- **Merge-Erkennung** — zeigt „Purge"-Badge, wenn der PR eines Branches gemergt wurde

#### Schnellaktionen {#quick-actions-1}

Aus der Seitenleiste Ein-Klick-Operationen ausführen: **Create PR** (KI-generierter Titel und Beschreibung), **Push** (zu Origin mit `-u`) oder **Close PR** (schließt mit Kommentar). Weil wenn du es satt hast, „now commit, push, and open a PR" zum hundertsten Mal in Claude zu tippen, bist du nicht allein.

### Updates {#updates}

Factory Floor zeigt ein Badge in der Seitenleiste, wenn eine neuere Version verfügbar ist. Du kannst auch manuell prüfen über **Factory Floor > Check for Updates...**

**Homebrew-Nutzer:**

```
brew upgrade factory-floor
```

**DMG-Nutzer:** Updates werden automatisch über [Sparkle](https://sparkle-project.org) verwaltet. Manuell prüfen über das Menü: **Factory Floor > Check for Updates...**

Aktiviere **Bleeding edge updates** in Settings > Advanced für Vorabversionen. Für alle, die gerne am Limit leben und Fehlerberichte einreichen.

---

## Enterprise-Funktionen 😉 {#enterprise-features-}

### Code-Editor {#code-editor}

Nö. Kein Syntax-Highlighting, kein Autocomplete, keine Minimap. Unsere nicht existierenden VCs haben keine Unternehmensagenda vorangetrieben. Wir wollen, dass du die Werkzeuge verwendest, die du bereits liebst: [Zed](https://zed.dev), [VS Code](https://code.visualstudio.com), was auch immer. Factory Floor gibt dir einen Coding-Agent, einen Browser und einen Worktree. Außerdem, wer schreibt heutzutage noch Code?

### Merge-Viewer {#merge-viewer}

Auch nö. Dein Git-Client macht das schon besser als wir es jemals könnten. Wir sorgen nur dafür, dass jeder Workstream einen sauberen Branch hat, der für Review bereit ist. Du hältst deine PRs doch klein und vermeidest Merge-Konflikte, oder? ...Oder?

---

## Fehlerbehebung {#troubleshooting}

#### „Tools not found" {#tools-not-found}

Factory Floor erkennt Tools aus deiner Login-Shell. Wenn `claude`, `gh`, `git` oder `tmux` nicht auftauchen:

- Stelle sicher, dass sie in deiner Shell-PATH sind
- Fish 4.0- und Nix-Nutzer: die App unterstützt diese Umgebungen, aber wenn etwas nicht stimmt, prüfe Settings > Environment

#### Tmux-Sitzungen bleiben nicht erhalten {#tmux-sessions-not-persisting}

- Überprüfe, dass tmux installiert und erkannt ist (Settings > Environment)
- Factory Floor verwendet seinen eigenen tmux-Socket (`-L factoryfloor`), deine persönliche tmux-Konfiguration stört also nicht

#### Port nicht erkannt {#port-not-detected}

- Stelle sicher, dass dein Run-Skript `$FF_PORT` verwendet (oder der Port aus dem Prozessbaum erkannt wird)
- Der `ff-run`-Launcher umhüllt das Run-Skript — er überwacht Kindprozesse nach lauschenden TCP-Ports
- Prüfe Settings > Advanced > Detailed logging für Debug-Ausgaben

#### Etwas anderes kaputt? {#something-else-broken}

- [Fehler melden](https://github.com/alltuner/factoryfloor/issues/new?template=bug_report.yml) — sag uns, was schiefgelaufen ist
- [Fix-Prompt einreichen](https://github.com/alltuner/factoryfloor/issues/new?template=fix_prompt.yml) — schreib den Prompt, wir lassen den Agenten ran
- [Etwas anderes](https://github.com/alltuner/factoryfloor/issues/new) — Ideen, Fragen, existenzielle Zweifel
