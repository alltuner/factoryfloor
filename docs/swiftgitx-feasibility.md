# SwiftGitX Feasibility Assessment

## What is SwiftGitX?

[SwiftGitX](https://github.com/ibrahimcetin/SwiftGitX) is a modern Swift wrapper
for [libgit2](https://github.com/libgit2/libgit2), created by Ibrahim Cetin in
June 2024. It provides a Swift-idiomatic API with typed throws, async/await for
network operations, and native SPM support.

- **Created:** June 2024
- **Stars:** 142
- **License:** MIT
- **Latest release:** 0.4.0 (December 1, 2025)
- **Last commit:** December 1, 2025
- **libgit2 version:** 1.9.2 (current upstream, via author's SPM-packaged fork)
- **Swift tools version:** 6.0
- **Contributors:** Effectively 1 (237 commits from ibrahimcetin, 2 from TimArt, 1 from adamwulf)

## Maintenance Status

**Actively developed by a solo maintainer.** The project went through a major
burst of activity in late November 2025 (Swift 6 support, typed throws,
automatic runtime management, test migration to Swift Testing, libgit2 1.9.2
upgrade) followed by a 0.2.0 -> 0.3.0 -> 0.4.0 release in one week.

Before that burst, there was a gap from September 2024 (0.1.7) to August 2025
(0.1.8/0.1.9), then another gap to November 2025. The project shows a "sprint
then pause" pattern rather than steady cadence.

Open issues: 2 (SIGPIPE during SSH fetch, merge/pull feature request as PR).
Closed issues: 11. The maintainer responds to issues within hours/days and
engages thoughtfully.

There is an open PR (#13) from the maintainer adding merge/pull support,
indicating continued feature development.

## libgit2 Integration

SwiftGitX depends on the maintainer's [fork of
libgit2](https://github.com/ibrahimcetin/libgit2) which adds a `Package.swift`
to build the C library directly via SPM. This is a clean approach: the Swift
compiler handles the C compilation, no xcframework or pre-built binary needed.
The fork tracks upstream libgit2 tags (1.8.0, 1.9.1, 1.9.2 available).

The libgit2 Package.swift is well-structured with platform-specific
configuration for macOS (CommonCrypto, SecureTransport) vs Linux (OpenSSL,
builtin SHA). It builds all of libgit2 including the worktree module.

**Key point:** The `include/git2/worktree.h` header is present and exposed
through the public headers. All libgit2 worktree C functions
(`git_worktree_add`, `git_worktree_list`, `git_worktree_prune`,
`git_worktree_lookup`, `git_worktree_validate`, etc.) are compiled and available
for Swift to call.

## Worktree Support

**SwiftGitX does not currently expose worktree operations.** There is no
`WorktreeCollection`, no `Repository+worktree.swift`, and no worktree-related
types in the source tree.

However, unlike SwiftGit2 (which was pinned to an old libgit2 with limited
worktree APIs), SwiftGitX ships libgit2 1.9.2 which has mature, full-featured
worktree support. The C functions are already compiled and linkable. What's
missing is the Swift wrapper layer.

### Effort to Add Worktree Support

The architecture is clearly extensible. Adding worktree support would follow
the established patterns:

1. **`Worktree` model** (like `Remote`, `Branch`): wraps `git_worktree` pointer,
   exposes `name`, `path`, `isValid`, `isLocked`. Estimated: ~50 lines.

2. **`WorktreeCollection`** (like `RemoteCollection`, `BranchCollection`):
   provides `list()`, `add(named:path:options:)`, `get(named:)`,
   `remove(_:)` / `prune(_:)`. Follows the exact same pattern as
   `RemoteCollection`. Estimated: ~100-150 lines.

3. **`Repository.worktree` property**: returns `WorktreeCollection`, same as
   `Repository.remote`, `Repository.branch`, etc. One line.

4. **Tests**: following the existing pattern in `Tests/SwiftGitXTests/`.
   Estimated: ~100 lines.

The C API surface we'd need to wrap:

| C Function | Swift Wrapper |
|---|---|
| `git_worktree_list` | `WorktreeCollection.list()` |
| `git_worktree_add` | `WorktreeCollection.add(named:path:ref:)` |
| `git_worktree_lookup` | `WorktreeCollection.get(named:)` |
| `git_worktree_validate` | `Worktree.isValid` |
| `git_worktree_prune` | `WorktreeCollection.prune(_:)` / `remove(_:)` |
| `git_worktree_name` | `Worktree.name` |
| `git_worktree_path` | `Worktree.path` |
| `git_worktree_free` | Handled in `deinit` or `defer` |

**Estimated effort: 1-2 days** for a clean implementation following existing
patterns, including tests. This is a straightforward PR, not a research project.

The maintainer has been responsive to PRs (all 10 merged PRs were merged within
hours/days). Contributing this upstream is realistic.

## Operations We Need vs. What SwiftGitX Supports

| Operation (GitOperations.swift) | SwiftGitX Support | Notes |
|---|---|---|
| `isGitRepo` (check .git dir) | Yes (`Repository.open(at:)` throws if not a repo) | Or keep the simple FileManager check |
| `initRepo` | Yes (`Repository.create(at:)`) | |
| `rev-parse --abbrev-ref HEAD` | Yes (`repository.HEAD` returns Branch with `.name`) | |
| `remote get-url origin` | Yes (`repository.remote["origin"]?.url`) | |
| `rev-list --count HEAD` | Partial (`repository.log()` returns `CommitSequence`, must count via iteration) | Same limitation as SwiftGit2 |
| `status --porcelain` | Yes (`repository.status()` returns `[StatusEntry]`) | Richer than porcelain output |
| `symbolic-ref refs/remotes/origin/HEAD` | Yes (`repository.reference["refs/remotes/origin/HEAD"]`) | |
| `rev-parse --verify <ref>` | Yes (via `ObjectFactory.lookupObject(revision:)` or reference lookup) | |
| **`worktree add -b <branch>`** | **No (but C API available)** | Needs Swift wrapper |
| **`worktree remove`** | **No (but C API available)** | Needs Swift wrapper |
| **`worktree list --porcelain`** | **No (but C API available)** | Needs Swift wrapper |
| **`worktree prune`** | **No (but C API available)** | Needs Swift wrapper |

## Technical Evaluation

### Strengths

- **Swift 6 with strict concurrency.** `Repository` is `final class` marked
  `Sendable`. Uses `nonisolated(unsafe)` for the C pointer (pragmatic
  approach, libgit2 operations are thread-safe when using separate repository
  handles). Typed throws with `throws(SwiftGitXError)`.

- **Current libgit2 (1.9.2).** Not pinned to a stale version. The maintainer
  actively updates the fork when new libgit2 versions ship.

- **Native SPM.** Clean `Package.swift`, no Carthage, no xcframework artifacts.
  Builds from source via SPM on all Apple platforms and Linux.

- **async/await for network ops.** Clone and fetch are `async`. Local operations
  are synchronous (appropriate since they're fast). The maintainer acknowledges
  the blocking-async issue in a TODO comment, which is honest.

- **Clean architecture.** Collection pattern (BranchCollection, RemoteCollection,
  etc.) is consistent and extensible. Factory pattern for creating Swift objects
  from C pointers. Error handling wraps libgit2 error codes into typed Swift
  errors with operation context.

- **Good error model.** `SwiftGitXError` captures code, category, operation
  context, and message. Typed throws propagate errors cleanly.

- **macOS 10.15+ support.** Far exceeds our macOS 14.0 requirement.

- **Test suite.** Uses Swift Testing framework. Tests cover repositories,
  branches, remotes, status, diffs, commits, stash, tags, fetch, push, clone.
  CI runs on macOS-latest.

### Concerns

- **Solo maintainer.** 99% of commits are from one person. If they lose
  interest, the project stalls. The sprint-pause commit pattern is a mild
  yellow flag.

- **Small community.** 142 stars, 15 forks, 3 subscribers. Limited real-world
  production usage to validate edge cases.

- **Missing operations.** No merge, no pull (PR #13 in progress), no rebase,
  no cherry-pick, no blame. We don't need these today, but they indicate the
  library is still pre-1.0 and incomplete.

- **SIGPIPE bug during SSH fetch** (issue #12). Seems to be a libgit2 SSH
  transport issue, not SwiftGitX-specific. Only affects SSH URLs. We don't
  do fetch/clone operations, so this doesn't impact us.

- **No worktree support yet.** The critical gap for our use case. However, as
  analyzed above, adding it is straightforward.

- **libgit2 fork dependency.** We depend on the maintainer keeping their fork
  updated. If they disappear, we'd need to maintain the fork or switch to our
  own. The fork is trivial (just adds Package.swift to upstream libgit2), so
  this is low-risk.

- **`nonisolated(unsafe)` for repository pointer.** This is a pragmatic choice
  that works correctly when each `Repository` instance is used from one
  context at a time. Factory Floor's `GitOperations` already runs all git
  calls from `Task.detached`, so this aligns with our usage pattern. But it
  means the library won't protect against concurrent access to the same
  `Repository` instance.

### XcodeGen Integration

Factory Floor uses XcodeGen, not raw SPM. Adding an SPM package dependency
in `project.yml` is supported:

```yaml
packages:
  SwiftGitX:
    url: https://github.com/ibrahimcetin/SwiftGitX.git
    from: "0.4.0"
```

Then add to the target's dependencies:

```yaml
dependencies:
  - package: SwiftGitX
    product: SwiftGitX
```

This is the same pattern used for swift-cmark, Sentry, and Sparkle. No
special build setup needed since libgit2 compiles from source via SPM.

## Comparison: Three Approaches

### Option A: Adopt SwiftGitX (contribute worktree support)

**Effort:** ~3 days (1 day integration, 1-2 days writing + upstreaming worktree
bindings, 1 day porting GitOperations.swift).

**Pros:**
- Type-safe git operations with structured error handling
- No Process() spawning, no PATH resolution, no blocking waitUntilExit
- No runtime dependency on git being installed
- Current libgit2 with active maintenance
- Swift 6 / Sendable compatible
- Clean SPM integration with XcodeGen

**Cons:**
- Solo maintainer risk (mitigated: we can fork if needed, library is small)
- Must write and maintain worktree bindings (mitigated: straightforward,
  ~200 lines)
- Pre-1.0 library with small community
- Adds ~50K lines of C code (libgit2) to the build graph

**Risk level:** Medium. The library is young but well-architected. The main
risk is the solo maintainer, but the codebase is small enough to fork and
maintain if needed.

### Option B: Keep Process() (current approach)

**Effort:** 0 days (already working).

**Pros:**
- Zero new dependencies
- Uses system git (always up-to-date, supports everything)
- Simple, proven, works today
- No C code in our build graph

**Cons:**
- Requires git to be installed (always true on macOS with Xcode/CLT)
- Opaque error handling (exit codes + stderr parsing)
- Process spawning overhead (negligible for our usage frequency)
- Must find git binary at startup

**Risk level:** Low. Known limitations are already mitigated.

### Option C: Direct libgit2 C interop (no wrapper library)

**Effort:** ~1-2 weeks (add libgit2 SPM dependency, write Swift wrappers for
the ~15 C functions we actually call, handle memory management, test).

**Pros:**
- No wrapper library dependency at all
- Only wrap what we need
- Full control over API surface

**Cons:**
- Must handle C pointer memory management manually
- Must write and maintain our own error handling for libgit2 codes
- More code to maintain than using SwiftGitX
- Reinvents what SwiftGitX already provides

**Risk level:** Medium-low technically, but poor ROI. We'd be writing a
mini-SwiftGitX from scratch.

## Recommendation

**SwiftGitX is viable, but the current Process() approach is still the pragmatic
choice.**

SwiftGitX is a significant improvement over SwiftGit2 in every dimension:
current libgit2, SPM support, Swift 6 compatibility, active maintenance, clean
architecture. The worktree gap is closable with modest effort. If we were
starting from scratch or if Process() had serious problems, SwiftGitX would be
the right call.

But our Process()-based GitOperations works reliably today. The theoretical
benefits of SwiftGitX (type safety, no process spawning, no git dependency) are
real but don't solve problems we're actually experiencing. The git binary is
always available on our target platform (macOS with developer tools). Our git
operations are infrequent (startup, every 15s refresh, workstream
create/archive) and fast.

### When to reconsider

Adopt SwiftGitX if any of these become true:

1. **We need git operations on a platform without git** (iOS companion app,
   visionOS).
2. **We need richer git integration** (inline diffs, blame, merge conflict
   resolution) where structured data from libgit2 is materially better than
   parsing git CLI output.
3. **Process() spawning becomes a measurable performance problem** (unlikely
   at current operation frequency).
4. **SwiftGitX reaches 1.0** and adds worktree support natively, removing the
   need for us to contribute it.

### If we do adopt it

1. Fork SwiftGitX, add worktree bindings following the Collection pattern.
2. Open PR upstream. If merged, depend on upstream. If not, depend on our fork.
3. Add `SwiftGitX` to `project.yml` packages.
4. Rewrite `GitOperations.swift` to use SwiftGitX's Repository API.
5. Keep the `run()` helper as a fallback for any operations SwiftGitX doesn't
   cover.
6. Estimated total effort: 3-5 days including testing.
