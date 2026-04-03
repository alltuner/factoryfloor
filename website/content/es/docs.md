---
title: Docs
translationKey: docs
hideInstall: true
layout: docs
---

## Primeros pasos {#getting-started}

Estamos en 2026. Construimos sobre tmux (2007), git worktrees (2015), terminals (1978, la era del VT100, cuando incluso [David](https://davidpoblador.com) era solo un proyecto de futuro), y renderizado por GPU (gracias [Mitchell](https://mitchellh.com) por [Ghostty](https://ghostty.org)). Herramientas viejas, trucos nuevos.

Necesitas dos cosas: un Mac y la vaga sensación de que tu flujo de trabajo podría ser mejor.

```
brew install --cask factory-floor
```

<a href="https://github.com/alltuner/factoryfloor/releases/latest/download/FactoryFloor.dmg" class="docs-download"><svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download DMG</a>

Factory Floor funciona mejor cuando tienes esto instalado (te avisará si falta algo):

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** — la razón de ser, básicamente
- **git** — probablemente ya lo tienes
- **[gh](https://cli.github.com/)** — GitHub CLI, para estado de PR y quick actions
- **[tmux](https://github.com/tmux/tmux)** — opcional, permite persistencia de sesión

#### Tus primeros 30 segundos {#your-first-30-seconds}

1. Abre Factory Floor
2. Arrastra un repositorio git al sidebar (o haz clic en **+** para elegir uno)
3. Pulsa **⌘N** para crear un workstream
4. Eso es todo. Ya estás programando con IA.

No necesitas archivos de configuración. Factory Floor detecta tu configuración de git, herramientas instaladas y conexiones de GitHub automáticamente.

---

## Conceptos básicos {#core-concepts}

Las tres cosas con las que interactuarás cada día.

### Proyectos {#projects}

Un proyecto es un repositorio git. Arrastra un directorio al sidebar o haz clic en el botón **+**. Factory Floor comprueba si es un repositorio git (y ofrece inicializar uno si no lo es).

La vista de proyecto muestra información del repositorio, detalles de GitHub (stars, forks, issues abiertas), hasta 5 PRs recientes y documentación markdown descubierta automáticamente en tu repositorio.

Los proyectos se ordenan por **Recientes** (última actividad) por defecto. Cambia a **A-Z** si eres de esos.

Haz clic derecho en un proyecto en el sidebar para acceso rápido: **Reveal in Finder**, **Open in External Terminal**, **Open on GitHub**, o **Remove** (los archivos se quedan en disco, no somos monstruos).

### Workstreams {#workstreams}

Un workstream es donde ocurre el trabajo. Cada uno tiene su propio git worktree, branch, terminal, coding agent y navegador. Están completamente aislados entre sí.

**⌘N** crea un nuevo workstream. Entre bastidores:

1. Obtiene la última branch por defecto del origin
2. Crea un git worktree con una branch nueva (con tu branch prefix, por defecto: `ff`)
3. Hace symlink de `.env` y `.env.local` del repositorio principal (si está habilitado)
4. Ejecuta el setup script (si está configurado)
5. Lanza el coding agent

La interfaz aparece al instante, la creación del worktree ocurre en segundo plano.

#### Workstream tabs {#workstream-tabs}

- **Info** (⌘I) — nombre de branch, estado del PR, documentación del proyecto
- **Agent** (⌘Return) — tu sesión de Claude Code
- **Environment** (⌘E) — controles de setup y run script
- **Terminal** (⌘T) — terminal tabs adicionales, tantos como quieras
- **Navegador** (⌘B) — navegador integrado con detección automática de port

#### Branch auto-rename {#branch-auto-rename}

Con **Auto-rename branch** habilitado en ajustes, el coding agent renombra tu branch para que coincida con la tarea en el primer prompt. Así `ff/coral-tidal-reef` se convierte en `ff/fix-login-timeout`.

#### Eliminar vs. purgar {#removing-vs-purging}

- **Remove** — mata terminals y agent, pero el worktree se queda en disco
- **Purge** — elimina permanentemente el worktree y la branch (pide confirmación si hay cambios sin commit)

Cuando un PR se fusiona, Factory Floor muestra un badge "Purge" para que sepas que es seguro limpiar.

### El Coding Agent {#the-coding-agent}

El tab de coding agent ejecuta [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) en un terminal integrado. Aparece justo después del tab Info en cada workstream.

#### Ajustes del agent {#agent-settings}

- **Bypass permission prompts** — salta los diálogos de confirmación. Útil si confías en tu agent (y te gusta vivir peligrosamente).
- **Tmux mode** — envuelve las sesiones del agent en tmux para que sobrevivan a reinicios de la app. Requiere tmux.
- **Auto-rename branch** — permite al agent renombrar la branch para que coincida con la tarea.
- **Agent Teams** — coordinación multi-agente experimental, cortesía de Claude Code. Confiamos en Anthropic, ¿no?

#### Quick actions {#quick-actions}

Las quick actions ejecutan tareas puntuales de Claude desde el sidebar:

- **Commit** — hace stage y commit con un mensaje generado por IA
- **Push** — hace push de la branch actual al origin
- **Create PR** — crea un pull request con título y descripción generados por IA
- **Abandon PR** — cierra el PR

Se ejecutan como llamadas `claude -p` en segundo plano. Activa **Quick action debug mode** en ajustes si quieres saber cómo se hace la salchicha. Confía en nosotros, [David](https://davidpoblador.com) pasó más tiempo del que puede admitir depurando comportamientos extraños ahí dentro.

---

## Tu espacio de trabajo {#your-workspace}

Terminals, navegadores y atajos de teclado, las herramientas dentro de cada workstream.

### Terminals {#terminals}

Los terminals se renderizan por GPU con [Ghostty](https://ghostty.org). Son rápidos.

- **⌘T** — nuevo terminal tab
- **⌘W** — cerrar tab (o Ctrl+D para salir del shell)
- **⌘1-9** — cambiar entre tabs
- **⌘Shift+[** / **⌘Shift+]** — recorrer tabs

Puedes arrastrar archivos y texto al terminal. Porque a veces el ratón está bien, la verdad.

**⌘Shift+E** abre el directorio del workstream en tu aplicación de terminal externa preferida.

### El navegador {#the-browser}

Cada workstream puede tener pestañas de navegador (⌘B). El navegador está integrado, no necesitas cambiar de ventana.

#### Detección de port {#port-detection}

Cuando tu run script inicia un servidor de desarrollo, Factory Floor detecta el port en escucha automáticamente y navega el navegador hacia él. No necesitas configurar nada. El launcher `ff-run` monitoriza el árbol de procesos buscando listeners TCP.

#### Navegación {#navigation}

- **⌘L** — foco en la barra de direcciones
- **⌘Shift+O** — abrir URL actual en tu navegador externo
- **⌘Click** — abre enlaces en tu navegador externo

El navegador muestra una página de error de conexión con un botón de reintentar si el servidor aún no está listo. Navegará automáticamente cuando se detecte el port.

### Atajos de teclado {#keyboard-shortcuts}

Factory Floor prioriza el teclado. Aquí está todo.

#### Global {#global}

| Atajo | Acción |
|----------|--------|
| ⌘N | Nuevo workstream (o proyecto, si no hay ninguno) |
| ⌘Shift+N | Nuevo proyecto |
| ⌘, | Ajustes |
| ⌘/ | Ayuda |

#### Workstream {#workstream}

| Atajo | Acción |
|----------|--------|
| ⌘Return | Foco en Coding Agent |
| ⌘I | Panel de Info |
| ⌘E | Environment |
| ⌘T | Nuevo Terminal |
| ⌘B | Nuevo navegador |
| ⌘W | Cerrar tab |
| ⌘L | Barra de direcciones (navegador) |
| ⌘0 | Volver al proyecto |
| ⌘1-9 | Cambiar tab |
| ⌘Shift+[ | Tab anterior |
| ⌘Shift+] | Tab siguiente |
| Ctrl+Shift+R | Reconstruir setup |
| Ctrl+Shift+S | Iniciar/reiniciar run |

#### Navegación {#navigation-1}

| Atajo | Acción |
|----------|--------|
| Ctrl+1-9 | Cambiar workstream (desde cualquier vista) |
| ⌘Shift+O | Abrir en navegador externo |
| ⌘Shift+E | Abrir en terminal externo |

---

## Configuración {#configuration}

Cómo automatizar las partes aburridas.

### Scripts y ciclo de vida {#scripts--lifecycle}

Coloca un `.factoryfloor.json` en la raíz de tu proyecto para automatizar el ciclo de vida del workstream.

```json
{
  "setup": "npm install",
  "run": "PORT=$FF_PORT npm run dev",
  "teardown": "docker-compose down"
}
```

| Hook | Cuándo se ejecuta |
|------|-------------|
| `setup` | Una vez, cuando se crea un workstream. Instalar dependencias, ejecutar migraciones, lo que sea. |
| `run` | Bajo demanda desde el tab Environment (⌘E). Envuelto en `ff-run` para detección de port. |
| `teardown` | Cuando se archiva o purga un workstream. Parar contenedores, limpiar. |

Todos los campos son opcionales. Los scripts se ejecutan en el directorio del workstream usando tu login shell. Sí, incluso [fish](https://github.com/alltuner/factoryfloor/pull/324). No preguntes cuánto tardó eso.

Factory Floor también lee `conductor.json` y `.superset/config.json` si `.factoryfloor.json` no existe. Porque la compatibilidad es de buena educación. (¿Es hora de un [estándar](https://xkcd.com/927/)?)

#### El tab Environment {#the-environment-tab}

Diseño en dos paneles: **Setup** a la izquierda, **Run** a la derecha.

- **Ctrl+Shift+R** — reconstruir (re-ejecuta setup)
- **Ctrl+Shift+S** — iniciar/reiniciar el run script

### Variables de entorno {#environment-variables}

Cada terminal, setup script y comando run en un workstream tiene estas variables:

| Variable | Qué es | Ejemplo |
|----------|-----------|---------|
| `FF_PROJECT` | Nombre del proyecto | `my-app` |
| `FF_WORKSTREAM` | Nombre del workstream | `coral-tidal-reef` |
| `FF_PROJECT_DIR` | Ruta del repositorio principal | `/Users/you/my-app` |
| `FF_WORKTREE_DIR` | Ruta del worktree | `~/.factoryfloor/worktrees/my-app/coral-tidal-reef` |
| `FF_PORT` | Port determinista (40001-49999) | `42847` |

#### Sobre FF_PORT {#about-ff_port}

Cada workstream recibe un port determinista basado en un hash de la ruta del worktree. Mismo workstream, mismo port, siempre. Sin conflictos de port entre workstreams. Úsalo en tu run script: `PORT=$FF_PORT npm run dev`. Si lo tuyo es ejecutar miles de workstreams simultáneamente, puede que tengas una colisión 🎲 pero esperemos que te quedes sin memoria antes.

#### .env symlink {#env-symlink}

Cuando está habilitado (Settings > General), Factory Floor hace symlink de `.env` y `.env.local` de tu repositorio principal a cada worktree. Así tus secretos te siguen sin copiar y pegar. Hablando de secretos, ¿te hemos hablado de [Vaultuner](https://vaultuner.alltuner.com)?

### Ajustes {#settings}

Abre con **⌘,** o haz clic en el icono del engranaje.

#### General {#general}

- **Base directory** — ubicación por defecto para nuevos proyectos
- **Branch prefix** — prefijo para branches de workstream (por defecto: `ff`)
- **Symlink .env files** — symlink automático de `.env` y `.env.local` a worktrees
- **Theme** — Sistema, Claro u Oscuro
- **Language** — Por defecto del sistema, English, Catalan, Spanish o Swedish
- **Confirm before quitting** — pregunta antes de cerrar con workstreams activos
- **Launch at login** — inicia Factory Floor al arrancar

#### Coding Agent {#coding-agent}

- **Bypass permission prompts** — desactiva la confirmación para acciones del agent
- **Agent Teams** — modo multi-agente experimental
- **Auto-rename branch** — el agent renombra la branch en el primer prompt
- **Tmux mode** — persistencia de sesión vía tmux

#### Apps {#apps}

- **External Terminal** — qué aplicación de terminal abrir con ⌘Shift+E
- **External Browser** — qué navegador para ⌘Shift+O y ⌘Click

#### Advanced {#advanced}

- **Usage analytics** — telemetry respetuosa con la privacidad (solo versión de la app, OS y locale)
- **Crash reports** — informes de crash basados en Sentry
- **Detailed logging** — registra la salida de scripts para depuración
- **Quick action debug mode** — muestra la salida cruda de las quick actions
- **Bleeding edge updates** — recibir builds pre-release
- **Clear project list** — opción nuclear, elimina todos los proyectos del sidebar

---

## Integraciones {#integrations}

Conectar Factory Floor con todo lo demás.

### CLI {#cli}

Instala el comando `ff` desde Settings > Environment > Install CLI. Luego:

```
ff /path/to/your/project
```

Abre el directorio en Factory Floor. Eso es todo lo que hace, y es todo lo que necesita hacer.

### GitHub {#github}

Requiere el [gh CLI](https://cli.github.com/) con autenticación (`gh auth login`).

- **Vista de proyecto** — info del repositorio, descripción, stars, forks, issues abiertas, PRs recientes
- **Workstream sidebar** — número de PR, título y estado (abierto/fusionado/cerrado) por branch
- **Detección de merge** — muestra badge "Purge" cuando el PR de una branch se ha fusionado

#### Quick actions {#quick-actions-1}

Desde el sidebar, ejecuta operaciones con un clic: **Create PR** (título y descripción generados por IA), **Push** (al origin con `-u`), o **Abandon PR** (cierra con un comentario). Porque si estás cansado de escribir "ahora haz commit, push y abre un PR" en Claude por centésima vez, no estás solo.

### Actualizaciones {#updates}

Factory Floor muestra un badge en el sidebar cuando hay una versión más nueva disponible. También puedes comprobarlo manualmente desde **Factory Floor > Check for Updates...**

**Usuarios de Homebrew:**

```
brew upgrade factory-floor
```

**Usuarios de DMG:** las actualizaciones se gestionan automáticamente vía [Sparkle](https://sparkle-project.org). Comprueba manualmente desde el menú: **Factory Floor > Check for Updates...**

Activa **Bleeding edge updates** en Settings > Advanced para builds pre-release. Para los que les gusta vivir al límite y reportar bugs.

---

## Funcionalidades Enterprise 😉 {#enterprise-features-}

### Editor de código {#code-editor}

No. Sin resaltado de sintaxis, sin autocompletado, sin minimapa. Nuestros VCs inexistentes no han estado presionando ninguna agenda corporativa. Nuestra intención es que uses las herramientas que ya te gustan: [Zed](https://zed.dev), [VS Code](https://code.visualstudio.com), lo que sea. Factory Floor te da un coding agent, un navegador y un worktree. Además, ¿quién escribe código ya?

### Visor de merge {#merge-viewer}

Tampoco. Tu cliente de git ya lo hace mejor de lo que nosotros haríamos nunca. Nosotros solo nos aseguramos de que cada workstream tenga una branch limpia lista para revisión. Mantienes tus PRs pequeños y evitas merge conflicts, ¿verdad? ...¿Verdad?

---

## Solución de problemas {#troubleshooting}

#### "Tools not found" {#tools-not-found}

Factory Floor detecta herramientas desde tu login shell. Si `claude`, `gh`, `git` o `tmux` no aparecen:

- Asegúrate de que están en el PATH de tu shell
- Usuarios de Fish 4.0 y Nix: la app gestiona estos entornos, pero si algo falla, revisa Settings > Environment

#### Las sesiones de tmux no persisten {#tmux-sessions-not-persisting}

- Verifica que tmux está instalado y detectado (Settings > Environment)
- Factory Floor usa su propio tmux socket (`-L factoryfloor`), así que tu configuración personal de tmux no interferirá

#### Port no detectado {#port-not-detected}

- Asegúrate de que tu run script usa `$FF_PORT` (o que el port se detecta del árbol de procesos)
- El launcher `ff-run` envuelve el run script, monitoriza los procesos hijos buscando ports TCP en escucha
- Revisa Settings > Advanced > Detailed logging para salida de depuración

#### ¿Algo más roto? {#something-else-broken}

- [Reportar un bug](https://github.com/alltuner/factoryfloor/issues/new?template=bug_report.yml) — cuéntanos qué salió mal
- [Enviar un fix prompt](https://github.com/alltuner/factoryfloor/issues/new?template=fix_prompt.yml) — escribe el prompt, dejaremos que el agent lo intente
- [Otra cosa](https://github.com/alltuner/factoryfloor/issues/new) — ideas, preguntas, dudas existenciales
