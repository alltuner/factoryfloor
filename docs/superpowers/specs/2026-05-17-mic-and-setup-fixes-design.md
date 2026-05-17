# Design: Microphone capture + Setup-script gate fixes

Date: 2026-05-17
Branch: `dy/split-deep-cfg`

## Problems

### 1. Embedded browser never gets microphone access
`getUserMedia({audio: true})` in the embedded `WKWebView` (`BrowserView`/`BrowserWebView`) silently fails — macOS never shows a TCC prompt.

Existing setup is correct but incomplete:
- `Info.plist` declares `NSMicrophoneUsageDescription` and `NSCameraUsageDescription` (project.yml:60, 65).
- Entitlements declare `com.apple.security.device.audio-input` and `com.apple.security.device.camera` (dy.entitlements, dy-local.entitlements).
- `WKUIDelegate.requestMediaCapturePermissionFor` is implemented in `BrowserView.swift:318-326` and grants automatically.

Missing piece: `BrowserWebView` is constructed with `BrowserWebView()` (TerminalContainerView.swift:2141) using the default `WKWebViewConfiguration`. On macOS, WKWebView's media-capture pipeline is gated by a configuration/preference flag. Without it, the WebKit process never invokes the permission delegate, never reaches AVCaptureSession, so the OS TCC layer is never prompted.

### 2. Setup script blocks the Agent tab
When a `.dockyard.json` declares a `setup` script, the Agent tab renders a setup "gate" (`setupGateRunningView`) running the script in a Ghostty terminal surface until exit. The coding agent (claude / codex / opencode) only launches after `handleSetupChildExited`.

Source of the gate:
- `TerminalContainerView.swift:1242-1247` — sets `setupGateState = .running` if `scriptConfig.setup != nil` and not previously completed.
- `TerminalContainerView.swift:588-593` — Agent tab body renders `setupGateRunningView` while gate is running/failed.
- `TerminalContainerView.swift:1289-1292, 1317-1340, 1342-1389` — gate command, view, and post-exit flow.
- `SetupStateStore` persists per-workstream completion in UserDefaults (TerminalContainerView.swift:52-82).

We want the Agent tab to launch the coding CLI immediately, regardless of setup state. Setup should run in the background.

## Out of scope
- Display-change resizing of inner views — the user reports this is already working.
- Camera capture parity — same fix applies; no separate work needed.

## Design

### Fix 1: Enable media capture in the embedded WKWebView

Create a single `BrowserWebView.makeConfiguration()` (or top-level `browserWebViewConfiguration()`) used by every `BrowserWebView` instance.

Two settings to set, in order of priority:
1. **Primary**: enable WebRTC media devices on `WKPreferences`. The supported public API path on macOS 14+ is to use `WKWebpagePreferences` for content settings and `WKPreferences` for engine settings. The WebRTC enable knob is exposed via private `WKPreferences` SPI keys that are widely used:
   - `preferences.setValue(true, forKey: "mediaDevicesEnabled")`
   - `preferences.setValue(true, forKey: "mediaStreamEnabled")`
   - `preferences.setValue(true, forKey: "peerConnectionEnabled")`

   These are private API but are stable and used broadly (Chrome, Edge for macOS, Brave embed WKWebView wrappers, etc.). They are required for `getUserMedia` to ever invoke the macOS permission delegate.

2. **Secondary**: make playback non-blocking on first interaction so capture flows aren't deferred:
   - `configuration.mediaTypesRequiringUserActionForPlayback = []`

Then construct `BrowserWebView(frame: .zero, configuration: config)` everywhere it is currently `BrowserWebView()`.

After the fix, the first time a page calls `getUserMedia({audio: true})`:
- WebKit reaches the `requestMediaCapturePermissionFor` delegate → we grant.
- AVCaptureSession requests microphone access via TCC.
- macOS shows the system prompt (because `NSMicrophoneUsageDescription` is set).
- User grants; subsequent calls work without prompting.

If after this change the prompt still doesn't appear, the most likely culprit is the debug bundle being unsigned beyond ad-hoc — the audio-input entitlement requires hardened runtime to be honored. Mitigation noted but no code change planned; release build uses hardened runtime already (release.sh).

### Fix 2: Move setup to a background `Process`

**Behavior change**:
- Agent tab launches the coding CLI immediately when a workstream opens, even if setup is pending or running. No more `setupGateRunningView`/`setupGateFailedView` rendering in the Agent tab.
- Setup runs invisibly via `Process` (not via a ghostty surface) when the workstream is first opened and `SetupStateStore.isCompleted(for: workstreamID) == false`.
- Status surfaces only in the Info tab: a small inline indicator ("Setup running…" / "Setup failed" with a retry button / nothing when done).
- On failure, surface a one-line banner at the top of the Info tab with the exit code and a "Show log" disclosure that prints the captured stdout/stderr tail. Optionally, a "Run in terminal" button that spawns a regular terminal tab running the setup script — for users whose setup actually needs interactivity.

**Trade-off (explicit)**: setup scripts that prompt for input (sudo password, interactive confirmations) will appear to hang. Today's `./scripts/setup.sh` doesn't, but third-party setups might. The "Run in terminal" escape hatch on failure covers this case.

**Implementation outline**:

1. New `SetupRunner` (Sources/Models/SetupRunner.swift):
   ```
   @MainActor final class SetupRunner: ObservableObject {
       enum State { case idle, running, succeeded, failed(exitCode: Int32) }
       @Published private(set) var state: State = .idle
       @Published private(set) var logTail: String = ""   // last ~4KB of stdout+stderr
       func start(script: String, workingDirectory: String, environmentVars: [String: String])
       func cancel()
   }
   ```
   - Uses `Process` with `process.executableURL = URL(fileURLWithPath: CommandBuilder.userShell)`, `arguments = ["-lic", script]`, `currentDirectoryURL` set, environment merged with `environmentVars`.
   - Pipes stdout+stderr into a `Pipe`, accumulates with a ring buffer cap (~4KB) into `logTail`.
   - On termination: state → `.succeeded` or `.failed(exitCode:)`, calls `SetupStateStore.markCompleted` only on success.

2. Wire-up in `TerminalContainerView`:
   - Replace the `.running`/`.failed` branches in Agent tab body (TerminalContainerView.swift:588-593) so the Agent tab only ever renders the loading view or the coding-CLI terminal.
   - Owner of `SetupRunner` is `TerminalContainerView` (one per workstream). Created lazily; started in `loadWorkstreamState`/equivalent init path where `setupGateState` is currently flipped to `.running`.
   - Remove `setupGateID`, `setupGateRunningView`, `setupGateFailedView`, `buildSetupGateCommand`, `handleSetupChildExited`, `launchAgentAfterSetup`. Remove `setupGateID` from `terminalChildExited` / `terminalTabExited` handlers (TerminalContainerView.swift:824-842). The `respawnableIDs.insert(agentID)` is unconditional now.
   - The agent terminal is preloaded immediately (no waiting on setup).

3. Info tab surface (`WorkstreamInfoView`):
   - Add a small `SetupStatusBanner` view rendered above the Run pane when `SetupRunner.state != .succeeded && setupConfig.setup != nil`.
   - Three visual states:
     - `.running`: small spinner + "Setup running…" + the script path in monospace + Cancel button.
     - `.failed`: yellow banner + "Setup failed (exit N)" + "View log" disclosure + "Retry" + "Run in terminal".
     - `.idle` with `setup` defined but not yet started (e.g. user opened an existing workstream where setup never completed): "Run setup" button.
   - When `.succeeded`, banner hidden entirely.

4. `SetupStateStore` semantics unchanged: only marked complete on exit code 0. Existing entries (workstreams already past the gate) keep working.

5. Localization keys for: "Setup running…", "Setup failed (exit %d)", "Run setup", "View log", "Retry", "Run in terminal". Added to en/ca/de/es/sv per CLAUDE.md.

### Failure modes / edge cases
- **Setup hangs forever (interactive prompt)**: visible to user as a permanent spinner in Info. Cancel terminates the Process. "Run in terminal" exists.
- **Process fails to spawn (e.g. shell missing)**: state → `.failed(-1)` with stderr in `logTail`.
- **Workstream closed mid-run**: `SetupRunner.cancel()` in `onDisappear` / archive flow. Terminate the Process and don't mark complete.
- **`.dockyard.json` lacks setup**: `SetupRunner` not created; banner not rendered. Existing behavior.

### Files touched
- `Sources/Views/BrowserView.swift` — add `browserWebViewConfiguration()` helper (or static method on `BrowserWebView`).
- `Sources/Views/TerminalContainerView.swift` — change `webView(for:)` to pass the config; remove gate plumbing.
- `Sources/Models/SetupRunner.swift` — new file.
- `Sources/Views/WorkstreamInfoView.swift` — render banner; observe `SetupRunner`.
- `Localization/*/Localizable.strings` — new keys (5 languages).
- `project.yml` — no change (new file picked up by `Sources/` glob; needs `xcodegen generate`).

### Tests
- `BrowserViewTests` (if/where it exists) — unit-test that `browserWebViewConfiguration()` flips the WebRTC keys. Skip if no equivalent test target exists; manual verification in dev build is acceptable for the WK side because the private-key SPIs aren't observable.
- `SetupRunnerTests` — start a short script (`/bin/true`), assert state transitions to `.succeeded` and `SetupStateStore.isCompleted` is true. Start a failing script (`/usr/bin/false`), assert `.failed(exitCode: 1)` and not marked complete. Capture some output and assert `logTail` is populated.
- Manual verification:
  - Create a fresh workstream → Agent tab launches the coding CLI immediately, Info tab shows "Setup running…" then hides on success.
  - Force a failure (rename `scripts/setup.sh`) → Info tab shows the failed banner with log tail.
  - Open the embedded browser to a getUserMedia test page (e.g., webcamtests, or a small local HTML) → macOS prompts for microphone the first time.
