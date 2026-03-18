# SwiftGit2 Feasibility Assessment

## What is SwiftGit2?

[SwiftGit2](https://github.com/SwiftGit2/SwiftGit2) is a Swift wrapper around
[libgit2](https://github.com/libgit2/libgit2), the C library that reimplements
Git's core methods as a linkable library. It exposes a Swift-idiomatic
`Repository` class with typed results (`Result<T, NSError>`) for clone, commit,
diff, status, branch/tag/remote listing, checkout, fetch, and reference
resolution.

- **Created:** 2014 (originally by GitHub employees)
- **Stars:** ~700
- **License:** MIT
- **Last tagged release:** 0.6.0 (May 2019)
- **Last commit:** September 2025 (CI dependency bump)

## Current Maintenance Status

**Effectively in maintenance mode.** The project has not shipped a release since
2019. Commits over the past two years are limited to CI fixes and build
compatibility patches (Xcode 15/16, arm64 runners). There are ~50 open issues,
many unanswered for years.

Key concerns:

- **Pinned to libgit2 v1.1.0** (October 2020). Current libgit2 is v1.9.2
  (December 2025). Five years of libgit2 improvements, including worktree
  enhancements and per-worktree config support (added in v1.8.0), are missing.
- **No SPM support on master.** Still uses Carthage and a fat binary. An open PR
  (#208) to migrate to SPM has been pending since March 2024 with 25 comments
  but no merge.
- **macOS 15 build failures** reported (issue #211) with no official fix merged
  to master.
- **No Swift 6 / Sendable conformance.** The `Repository` class is a non-final
  reference type with no concurrency annotations.
- **No worktree API exposed** (confirmed: issue #156 is open since 2019, zero
  comments; `Repository.swift` has zero worktree references).

## Operations We Need vs. What SwiftGit2 Supports

| Operation (GitOperations.swift) | libgit2 API | SwiftGit2 | Notes |
|---|---|---|---|
| `isGitRepo` (check .git dir) | `git_repository_open` | Yes (`Repository.at()`) | |
| `initRepo` | `git_repository_init` | Yes (`Repository.create()`) | |
| `rev-parse --abbrev-ref HEAD` | `git_repository_head` + ref name | Yes (`Repository.HEAD()`) | |
| `remote get-url origin` | `git_remote_lookup` | Yes (`Repository.remote(named:)`) | |
| `rev-list --count HEAD` | `git_revwalk` iteration | **Partial** (must iterate and count manually via `CommitIterator`) | |
| `status --porcelain` | `git_status_list` | Yes (`Repository.status()`) | |
| `symbolic-ref refs/remotes/origin/HEAD` | `git_reference_resolve` | Yes (`Repository.reference(named:)`) | |
| `rev-parse --verify <ref>` | `git_revparse_single` | **Not directly exposed**, but achievable via reference lookup | |
| **`worktree add -b <branch>`** | `git_worktree_add` | **No** | Critical gap |
| **`worktree remove`** | `git_worktree_prune` | **No** | Critical gap |
| **`worktree list --porcelain`** | `git_worktree_list` | **No** | Critical gap |
| **`worktree prune`** | `git_worktree_prune` | **No** | Critical gap |

**Worktree operations are the core of Factory Floor's workstream lifecycle, and
SwiftGit2 does not support any of them.**

## Benefits (if it worked)

- No `Process()` spawning, no `waitUntilExit()` blocking
- No PATH resolution needed to find the git binary
- No shell escaping concerns
- Type-safe error handling instead of opaque stderr strings
- Potentially async-friendly (could wrap libgit2 calls in `Task.detached`)
- No runtime dependency on git being installed

## Risks and Blockers

1. **No worktree support.** This is a hard blocker. Worktree operations are
   Factory Floor's most important git operations, and SwiftGit2 does not expose
   them. The underlying libgit2 v1.1.0 that SwiftGit2 bundles does have
   worktree APIs, but nobody has written Swift bindings for them.

2. **Stale libgit2.** Pinned to v1.1.0 (2020) vs current v1.9.2. Missing five
   years of bug fixes, security patches, and feature improvements (including
   better worktree support added in v1.8.0).

3. **No SPM support.** Factory Floor uses XcodeGen, and integrating a
   Carthage-only dependency adds build complexity. The SPM migration PR has
   stalled.

4. **Swift 6 incompatibility.** No `Sendable` conformance, no structured
   concurrency support. `Repository` is a reference type with mutable state and
   no thread-safety guarantees. Would generate warnings under strict concurrency.

5. **macOS 15 build issues.** Reported but not resolved on master.

6. **Maintenance trajectory.** Original maintainer (mdiep, GitHub employee) has
   not been active. Current activity is limited to community-contributed CI
   patches. No roadmap, no releases planned.

## Alternatives Considered

### SwiftGitX
[SwiftGitX](https://github.com/ibrahimcetin/SwiftGitX) is a more modern Swift
wrapper for libgit2 with SPM support, async/await, and throwing functions. 142
stars, created June 2024, actively developed. However, it also **lacks worktree
support** (no worktree files in source tree). It's a solo developer project with
limited community adoption.

### Direct libgit2 via C interop
Could import libgit2 directly as a C module and write our own Swift wrappers for
just the functions we need. libgit2 has full worktree support
(`git_worktree_add`, `git_worktree_list`, `git_worktree_prune`). This gives
maximum control but requires maintaining C interop code, building libgit2 as an
xcframework, and handling memory management for libgit2's pointer-based API.

### ObjectiveGit
[ObjectiveGit](https://github.com/libgit2/objective-git) is the Objective-C
binding for libgit2. Essentially abandoned: pinned to libgit2 v0.28.1 (even
older than SwiftGit2), no SPM support, no recent activity.

### Keep shelling out to git (current approach)
The `Process()` approach has real downsides but also genuine advantages: it uses
whatever git version the user has installed (always up-to-date), supports every
git operation with zero binding work, and the implementation is simple. The
blocking issue can be addressed by wrapping calls in `Task.detached` (which the
codebase already does in `AppEnvironment`).

## Recommendation: Do Not Adopt

**SwiftGit2 is not a viable option for Factory Floor.** The missing worktree
support is a hard blocker, and the project's maintenance trajectory does not
suggest it will be added. The stale libgit2 version, lack of SPM support, and
Swift 6 incompatibility compound the problem.

None of the alternatives fully solve the problem either. SwiftGitX and
ObjectiveGit also lack worktree support. Direct libgit2 integration is
technically possible but would be a significant undertaking for marginal benefit.

### What to do instead

The current `Process()`-based approach is the pragmatic choice. To address its
known issues:

1. **Blocking calls:** Already mitigated. `AppEnvironment` wraps all
   `GitOperations` calls in `Task.detached`. The `run()` helper blocks a
   background thread, not the main thread.

2. **PATH resolution:** Already handled by `CommandLineTools.path(for:)`. This
   is a one-time lookup.

3. **Shell escaping:** Not actually a concern. `Process` with `arguments` array
   does not invoke a shell, so no escaping is needed. Arguments are passed
   directly to the executable.

4. **Error messages:** Could be improved by parsing stderr in `run()` and
   returning structured errors instead of `nil`. This is a small, incremental
   improvement that doesn't require a library change.

## Migration Effort Estimate (if we did it anyway)

If someone were to attempt a libgit2-based approach (either via SwiftGit2 fork
or direct C interop):

- **Build system:** 2-3 days to set up libgit2 xcframework build, integrate
  with XcodeGen, and get CI working.
- **Worktree bindings:** 3-5 days to write and test Swift wrappers for
  `git_worktree_add`, `git_worktree_list`, `git_worktree_prune`, and related
  branch creation.
- **Port existing operations:** 2-3 days to rewrite `GitOperations.swift` and
  `GitHubOperations.swift` (though `gh` CLI calls would remain as Process).
- **Testing:** 2-3 days for integration tests with real repos.
- **Ongoing maintenance:** Keeping libgit2 updated, fixing platform-specific
  build issues, handling new libgit2 API changes.

**Total: ~2-3 weeks of focused work**, plus ongoing maintenance burden. Not
justified given the current approach works and its downsides are already
mitigated.
