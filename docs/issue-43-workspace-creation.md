# Issue #43: Production Workspace Creation Failure

## Summary
Clicking the "+" button to add a workstream in the production DMG build shows the
onboarding view instead of creating a workstream. Debug builds and local Release
builds work correctly.

## Root Cause
SwiftUI `@State` is a value type with copy-on-write semantics. In Release builds
(compiled with `-O` / `-Owholemodule`), the Swift optimizer causes `@State` mutations
in one closure to create a different snapshot than what another computed property sees
within the same update cycle. The `addWorkstream` function mutates `projects` (via
`@Binding` backed by `@State`), then sets `selection`. When SwiftUI re-evaluates
`activeProject`, it reads a snapshot of `projects` that doesn't include the new workstream.

## Evidence
Console.app logs (with `privacy: .public` Logger):
```
[FF] addWorkstream: worktree created at .../clean-slow-index
[FF] addWorkstream: done, posted notification
[FF] workstreamCreated notification handled: clean-slow-index   <-- mutation runs
[FF] activeProject: workstream 3CDD5AD9... not found in any project  <-- but not visible here
[FF] selection changed: ... -> workstream(3CDD5AD9...)
```
The mutation executes (confirmed by logs), but `activeProject` can't find the workstream
1ms later. This only happens in Release builds.

## Build Environment Differences

### Local Debug Build
- `./scripts/dev.sh build` or `./scripts/dev.sh br`
- Configuration: Debug (`-Onone`, no optimizations)
- Code signing: ad-hoc (`Sign to Run Locally`)
- Hardened runtime: NO
- `com.apple.security.get-task-allow`: YES (auto-injected)
- SwiftUI state: synchronous propagation, no snapshot coalescing

### Local Release Build
- `./scripts/dev.sh release`
- Configuration: Release (`-O`, `-Owholemodule`)
- Code signing: ad-hoc with `--options=runtime`
- Hardened runtime: YES
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`
- Xcode version: local (check with `xcodebuild -version`)

### CI Release Build (Production DMG)
- GitHub Actions runner: `macos-15` (macOS 15.7.4)
- Xcode: 16.4 (as of March 2026)
- Configuration: Release with whole-module optimization
- Code signing: Developer ID Application (ALL TUNER LABS S.L.)
- Hardened runtime: YES
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`
- `OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"`
- Entitlements: only `com.apple.security.app-sandbox = false`
- Notarized and stapled
- Packaged as DMG, distributed via Homebrew cask

### Key Difference
The CI runner's Xcode 16.4 may have a different SwiftUI runtime than the local Xcode.
SwiftUI's state batching behavior varies between SDK versions, especially in Release
builds where the optimizer can reorder operations.

## Approaches Tried (All Failed)

### 1. Direct @Binding Mutation (Original, v0.1.7)
```swift
// In ProjectSidebar (child)
projects[index].workstreams.append(workstream)  // @Binding
selection = .workstream(workstream.id)           // @Binding
```
**Why it failed:** @Binding writes don't propagate to parent @State before
SwiftUI re-evaluates the parent's computed properties in Release builds.

### 2. Callback to Parent (v0.1.18)
```swift
// Callback executes in ContentView's closure
onWorkstreamAdded: { projectID, workstream in
    projects[index].workstreams.append(workstream)  // @State
    selection = .workstream(workstream.id)           // @State
}
```
**Why it failed:** Closures in SwiftUI view bodies capture stale @State
snapshots in Release builds. The `projects` in the closure is a value-type
copy from when the view body was last evaluated.

### 3. DispatchQueue.main.async (v0.1.17)
```swift
projects[index].workstreams.append(workstream)
DispatchQueue.main.async { selection = .workstream(wsID) }
```
**Why it failed:** Even deferred to next run loop, the @State snapshot
issue persists.

### 4. DispatchQueue.main.asyncAfter 50ms (v0.1.19)
```swift
projects[index].workstreams.append(workstream)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
    selection = .workstream(wsID)
}
```
**Why it failed:** Same @State snapshot issue. The 50ms delay is visible
in logs but the workstream is still not found.

### 5. NotificationCenter with onReceive (v0.1.20)
```swift
// ProjectSidebar posts notification
NotificationCenter.default.post(name: .workstreamCreated, ...)

// ContentView receives via onReceive
.onReceive(publisher(for: .workstreamCreated)) { notification in
    projects[index].workstreams.append(workstream)
    selection = .workstream(workstream.id)
}
```
**Why it failed:** SwiftUI's `onReceive` closure has the same stale
@State snapshot problem as callbacks.

### 6. ObservableObject (v0.1.21 - Current Fix)
```swift
final class ProjectList: ObservableObject {
    @Published var items: [Project]
}

struct ContentView: View {
    @StateObject private var projectList = ProjectList()
    private var projects: [Project] {
        get { projectList.items }
        nonmutating set { projectList.items = newValue }
    }
}
```
**Why this should work:** `@Published` on a class uses heap-allocated
storage (reference semantics). When any closure mutates `projectList.items`,
all other code accessing `projectList.items` sees the same heap object.
No copy-on-write snapshot issues.

## Related Issues
- The same @Binding/@State timing bug affected `addProject` (drag-and-drop
  to empty sidebar caused crash/onboarding view)
- Tmux env vars were a separate issue (fixed in v0.1.14 with `-e` flags)
- NSLog privacy redaction was a separate issue (fixed with `Logger` and
  `privacy: .public`)

## Lessons Learned
1. Never rely on @State/@Binding propagation timing in Release builds
2. For shared mutable state across SwiftUI views, use ObservableObject
3. Always test with `./scripts/dev.sh release` before shipping
4. NSLog is redacted in Console.app for Release builds; use Logger with privacy: .public
5. Match CI Xcode version locally to reproduce production-only bugs
