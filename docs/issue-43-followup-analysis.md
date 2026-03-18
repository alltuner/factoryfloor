# Issue #43: Follow-up Analysis

## Current status

As of commit `c0568c8` (`fix: use ObservableObject for projects to fix Release @State timing (#43) (#63)`),
the production workspace creation issue appears to be fixed in practice.

That is important, but it does **not** prove the root-cause document is fully correct.
The latest change is small enough that it narrows the problem space, but it does not isolate
the exact SwiftUI failure mode with scientific certainty.

## What changed in the fix

The fix did **not** rewrite the workstream creation flow.

These parts stayed the same:

- `ProjectSidebar.addWorkstream()` still creates the git worktree and posts `.workstreamCreated`
- `ContentView` still receives the notification, appends the new workstream, and sets `selection`
- `activeProject` still derives the selected project by scanning the current `projects`

The meaningful change was only this:

- `projects` moved from `@State [Project]` to `@StateObject ProjectList`
- reads and writes now go through `projectList.items`

That makes the existing explanation plausible: changing the storage owner from value-backed SwiftUI
state to reference-backed observable state was enough to stop the bad behavior.

## What this fix proves

It strongly suggests the failure was caused by **state ownership / state visibility inside SwiftUI update cycles**,
not by git worktree creation, not by tmux, not by notarization, and not by the file persistence layer.

More specifically, it suggests the bug lived in the path between:

1. appending the new workstream
2. switching selection to that workstream
3. recomputing `activeProject`

The evidence fits a SwiftUI state propagation problem much better than an application logic problem.

## What is still not proven

### 1. The document may overstate `@State` copy-on-write as the exact cause

The current write-up treats the issue as definitively caused by `@State` value snapshots in Release builds.
That may be true, but the code does not isolate that variable cleanly enough to call it proven.

Other closely related explanations would also fit the evidence:

- a SwiftUI closure capture issue around state reads during the same render/update pass
- an optimizer-sensitive bug in nested mutation of value state
- a timing issue between one invalidation source (`selection`) and another (`projects`)

These are all in the same family, but they are not identical claims.

### 2. `ObservableObject` is probably helping, but not necessarily for the exact reason stated

The fix description says the class-backed storage solves the issue because every reader sees the same heap object.
That is directionally reasonable, but the code still mutates nested array state like this:

- `projects[index].workstreams.append(workstream)`

where `projects` is now a computed proxy over `projectList.items`.

That means the fix is still relying on Swift's read-modify-write behavior for a nested value mutation.
So the true win may be:

- different invalidation timing
- different closure capture semantics
- different storage lifetime/identity during view recomputation

not necessarily just "reference semantics fix everything".

### 3. The observation story is still a little muddy

`ProjectList.items` is `@Published`, but the code usually mutates inside the array rather than reassigning the whole array.
In SwiftUI/Combine, nested mutation of a published collection can be subtle.

That matters because the UI may currently be working thanks to the combination of:

- `projectList.items` changing
- `selection` changing
- SwiftUI recomputing the body for either or both reasons

So the system may now be stable, while the exact notification/invalidation mechanism remains ambiguous.

## My best current hypothesis

The failure was probably caused by **splitting a logically atomic state transition across SwiftUI-managed value state**:

- first mutate the project list
- then switch selection
- then immediately derive `activeProject` from the updated selection

In Debug, SwiftUI happened to evaluate this in a forgiving order.
In optimized Release builds from CI/Xcode 16.4, the same code path observed a stale view of `projects`
while already using the new `selection`.

The `ProjectList` change likely fixed it because it changed how SwiftUI observed and re-read the underlying state,
not because `NotificationCenter` or the append logic itself became inherently safe.

## Why I do not think the disk-side code is the culprit

I do not see evidence that the worktree is missing or malformed at the moment of failure.

Reasons:

- logs already showed `createWorktree` succeeding
- the bug manifested as the onboarding view, which comes from selection resolution in `ContentView`
- the broken path was `activeProject == nil` for the new workstream selection
- the latest fix did not touch `GitOperations.createWorktree`, persistence, or archive logic

If the worktree creation were the real cause, this commit should not have fixed it.

## The main architectural smell that remains

Even if the issue is fixed, the flow is still more indirect than it should be:

- child view performs side effects
- child view posts a notification
- parent view mutates model state
- parent view updates selection
- derived state decides whether to show the main UI or onboarding

That is a lot of moving parts for one user action.

My outside-the-box read is that the bug hunt became hard partly because the app is using
`NotificationCenter` to coordinate state that really belongs to a single owner.
That does not mean notifications caused the bug, but they definitely made the failure harder to reason about.

## What I would treat as the practical takeaway

The latest fix is probably real, but the root-cause doc should be read as a **working theory with strong supporting evidence**,
not a final proof.

The safe engineering takeaway is:

- avoid splitting related selection/model mutations across separate SwiftUI state owners
- prefer one owner for "append workstream + select workstream"
- be suspicious of Release-only behavior around derived state computed immediately after mutation

## What would actually prove the root cause

If we want certainty later, the cleanest proof would be a minimal reproduction that compares:

1. `@State var items: [Value]`
2. `@StateObject var store: Store` with `@Published var items: [Value]`
3. nested mutation plus immediate derived lookup after selection change
4. Debug vs optimized Release on the same Xcode version

If only case 1 fails and case 2 consistently passes, the current explanation becomes much stronger.
Until then, I would call the bug **very likely related to SwiftUI state semantics under optimization**, but not fully proven.
