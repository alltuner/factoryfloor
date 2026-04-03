# Corner Office — Remote Coordinator Design

## Overview

Corner Office is a lightweight coordinator that assigns work, demands status updates,
and takes credit for the results. Ships as a Docker container because even management
needs to be containerized these days.

**Name**: Corner Office
- Docker image: `factoryfloor/corner-office`
- Hosted URL: `corner-office.factory-floor.com`
- In-app setting: "Connect to Corner Office"

## Architecture

```
[Web UI] --> [Coordinator Container] <--poll-- [Factory Floor A]
                                     <--poll-- [Factory Floor B]
```

- **Coordinator**: thin REST API + minimal web UI. No terminal views, no agent runtime.
- **Factory Floor instances**: the workers. They do everything they already do (worktrees,
  agents, terminals). They poll the coordinator for jobs and push status updates.
- **Web UI**: fire new workstreams, check status. Lightweight dashboard, not a full client.

## Key decisions

### Coordinator is a dispatcher, not a runtime

The coordinator never runs agents or manages worktrees. It only says "open a workstream
with this prompt on this repo" and receives status back. All orchestration stays in the
Mac app.

### WebSocket by default, polling fallback

WebSocket is the primary transport. Status updates push immediately to the web UI and
connected clients. Polling (HTTP, 3-5s interval) is available as a fallback for
restrictive networks or proxies that don't support WebSocket upgrade.

### Fire and forget

Corner Office is a job board, not a remote control. You post work, workers pick it up,
you check results later. There is no job cancellation, no remote kill, no interactive
control. You enqueue a request and at best you get a status update. "Tomorrow when you
go to the office you will see what the factory has built."

### Device pairing (same flow for self-hosted and hosted)

No passwords, no API keys, no config files. Uses the device authorization pattern
(same UX as Netflix on a TV, GitHub CLI, Apple TV):

1. User enters the Corner Office URL in Factory Floor settings
   (e.g., `localhost:8080` or `corner-office.factory-floor.com`)
2. Factory Floor connects and receives a 6-character pairing code + QR code
3. Factory Floor displays both prominently in a pairing screen
4. User opens the Corner Office web UI (or scans the QR code), enters the code
5. Corner Office confirms the pairing and issues a token
6. Factory Floor stores the token locally, uses it for all subsequent connections
7. Pairing code expires after 5 minutes, single use

This is the only auth mechanism. Same code path for self-hosted and hosted. An exposed
Corner Office URL is useless until someone physically confirms a pairing code.

Re-pairing (after a token reset or new instance) is just: show a new code, confirm again.

### Factory Floor UX for connecting

The connection setup needs to be polished, first-class UI:

- **Settings panel**: a "Corner Office" section with a URL field
  (placeholder: `localhost:8080`). Clear labeling, not buried in advanced settings.
- **Connection status**: visible indicator (connected / disconnected / pairing) in the
  sidebar or status bar.
- **Pairing screen**: when first connecting to a new coordinator, Factory Floor shows a
  dedicated pairing view with the code in large text and a QR code. Not a modal, not a
  toast, a full screen that guides the user through the process.
- **QR code**: encodes the Corner Office web UI URL with the code pre-filled, so scanning
  it opens the browser directly to the confirmation page. Zero typing on the web side.
- **Error states**: clear messaging for "coordinator unreachable," "token expired,"
  "pairing rejected." Not technical errors, human-readable guidance.

### Corner Office web UI for pairing

- Landing page shows connected instances and a "Pair new instance" button
- Pairing page: single input field for the 6-character code, big confirm button
- After confirmation: instance appears in the dashboard immediately

## API surface (sketch)

### Factory Floor → Coordinator

- `POST /api/register` — announce instance (UUID, machine name, project names)
- `GET  /api/jobs?instance={uuid}` — poll for pending jobs (fallback transport)
- `POST /api/jobs/{id}/status` — push status update (running, done, failed, etc.)

### Web UI / integrations → Coordinator

- `GET  /api/instances` — list connected instances and their projects
- `POST /api/jobs` — dispatch a new job (project name, prompt, optionally target instance)
- `GET  /api/jobs` — list jobs with status

## Deployment models

Two deployment options sharing the same protocol:

### Self-hosted coordinator (power users)

Docker container users deploy wherever they want. No auth (on-prem trust model: if you
can reach it, you're authorized).

```bash
docker run -p 8080:8080 factoryfloor/coordinator
```

Factory Floor connects to `localhost:8080` or the container's network address.

Remote access is the user's responsibility. Documented recipes for:

- **Plain port**: expose directly on corporate network / VPN
- **Cloudflare Tunnel**: free tier, requires Cloudflare account + domain on CF DNS.
  Stable subdomain, unlimited tunnels, no inbound ports. `cloudflared` runs alongside
  coordinator.
- **Tailscale**: free for 100 devices / 3 users. Best for teams already on Tailscale.
  No domain needed. Coordinator container runs `tailscaled`, joins tailnet via auth key.
- **ngrok**: easiest setup (one token), but free tier has 20 conn/min rate limit and
  one static domain per account.

### Hosted coordinator (factory-floor.com)

Managed service for users who want zero infrastructure. Factory Floor instances connect
outbound to `coordinator.factory-floor.com` (HTTPS, works through any firewall).

Onboarding flow:
1. Sign in with GitHub/Google at coordinator.factory-floor.com
2. Get a pairing code
3. Paste code into Factory Floor settings
4. Factory Floor connects outbound. Done.

Auth: OAuth with GitHub/Google. No passwords, no signup forms.

## Business model

The app stays free and open-source. The hosted coordinator is the paid product.

**Free tier**
- 1 Factory Floor instance
- Limited workstreams/month (enough to evaluate)
- Status dashboard

**Pro tier**
- Multiple instances
- Higher job quotas
- Job history, webhook integrations
- Port forwarding for dev servers (ngrok-style)

Self-hosted coordinator always has full feature parity. No artificial gating. Competing
on convenience, not captivity. Self-hosters are still evangelists who bring Factory Floor
to teams that will pay for hosted.

## Coordinator implementation

Likely a small Go or Node service with:
- In-memory map of connected instances
- SQLite for job history
- Web UI: server-rendered HTML or minimal SPA

## State and persistence

- Job history: SQLite in a mounted volume
- Instance registry: in-memory, rebuilt from polling
- Repo availability: instances announce what repos they have locally

## Future extensions

- Expose detected ports from worker machines (ngrok-style reverse tunnel)
- CI/CD integration (webhook triggers jobs)
- Slack/chat bot integration via REST API

## Known gaps (from critical review)

### Job lifecycle
- Fire and forget: no cancellation. But completion artifacts need definition: branch
  name, PR URL, summary of changes, error details for failures.
- Staleness: WebSocket drop = Corner Office immediately knows the instance is gone.
  No heartbeat needed (the connection is the heartbeat). Polling fallback uses a TTL.

### Status model

Instance statuses:
- **Online** — connected, ready for work
- **Busy** — connected, has running workstreams
- **Disconnected** — WebSocket dropped (show last seen time)

Job statuses:
- **Queued** — waiting for an instance to pick it up
- **Running** — instance confirmed it started
- **Completed** — success (with branch, PR link, summary)
- **Failed** — instance reported failure (with error details)
- **Interrupted** — was running when the instance disconnected ("go check your Mac")

On reconnect, Factory Floor reports its actual state and Corner Office reconciles
(interrupted jobs may become running or completed).

### Project identity
- Corner Office knows project names and instance names. Nothing about git, paths, or
  worktrees. Factory Floor announces its registered projects by name.
- If a job targets a project no connected instance has, reject it.
- If multiple instances have the same project name, routing strategy TBD (user picks
  instance, round-robin, least loaded).

### Security surface
- Device pairing solves accidental exposure: an open Corner Office URL is useless until
  a code is confirmed. But paired tokens need secure storage and rotation strategy.
- Self-hosted and hosted use identical pairing flow. No separate auth code paths.

### Protocol versioning
- `/api/v1/` prefix from day one. Both sides send their version on connect. Incompatible
  versions show a clear upgrade message.
- Corner Office is dumb by design. It relays and stores messages it doesn't fully
  understand. New fields in status updates get stored and displayed even if Corner Office
  doesn't know what they are. New job parameters get passed through.
- Factory Floor is the smart one that evolves. Corner Office barely changes because it
  barely does anything. Backwards compatibility effort falls on keeping Corner Office's
  thin protocol stable, which is easy because the protocol is thin.
- Common case: Factory Floor updates frequently (auto-update), Corner Office sits at an
  old Docker tag for months. This is fine because Corner Office is a passthrough.

### User model
- No organizations, no teams, no permissions. A user connects 1..N Factory Floor
  instances and sees all of them. Each user sees only their own instances and jobs.
- Self-hosted: single implicit user (no login needed, everything is yours).
- Hosted: user identity via OAuth (GitHub/Google). One user account, all their
  instances and jobs under it.

### Web UI layout
Main view is a hierarchy: instances → projects → workstreams.
If there's only one instance, skip the instance level and show projects directly.
The instance is implicit. Switch to the grouped view when a second instance connects.

- **Instances**: name, status (online/busy/disconnected), last seen
- **Projects** (per instance): name, description (from `.factoryfloor.json`)
- **Workstreams** (per project, optional): status, branch, prompt snippet, metadata.
  Remote jobs (pushed from Corner Office) are visually distinct from local ones.
- **Push a task**: pick a project, write a prompt, send. Minimal form.
- **Pairing**: in settings/gear, not taking space in the main view.

### Remote work in Factory Floor
Factory Floor needs a concept of "remote work": workstreams dispatched from Corner
Office are tagged so the user can see "these were pushed remotely" vs "these I started
locally." Visible in the sidebar or workstream info.

### Transport
- WebSocket is primary, polling is fallback. Cloudflare Quick Tunnels don't support
  WebSocket/SSE, so they're only viable in polling-fallback mode.

### Project metadata
- Corner Office needs project names and descriptions to display in the web UI.
- Source of truth: `.factoryfloor.json` in the project directory (already has setup/run/
  teardown). Add `name` and `description` fields.
- Factory Floor reads the file, shows it locally (sidebar, info panel), and announces
  it to Corner Office.
- Editable from Factory Floor UI (writes back to file). Power users edit JSON directly.
- This is useful standalone (sidebar tooltips) and a prerequisite for Corner Office.

## Related documents

- [Mobile App Design](mobile-app-design.md) — future mobile client for Corner Office

## Open questions

- Multi-instance job routing: if multiple instances have the same project, how to pick
  one? (Round-robin? Least loaded? User picks?)
- Reconnection reconciliation: when a Factory Floor instance reconnects after a drop, does
  the coordinator ask "what are you running?" to rebuild state?
