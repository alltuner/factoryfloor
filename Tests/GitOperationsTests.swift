// ABOUTME: Tests for GitOperations worktree resolution.
// ABOUTME: Validates detection of worktree directories and resolution to main repository.

@testable import FactoryFloor
import XCTest

final class GitOperationsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - mainRepositoryPath

    func testMainRepositoryPathReturnsNilForNonGitDirectory() throws {
        let plainDir = tempDir.appendingPathComponent("plain")
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        XCTAssertNil(GitOperations.mainRepositoryPath(for: plainDir.path))
    }

    func testMainRepositoryPathReturnsNilForMainRepo() throws {
        let repoDir = tempDir.appendingPathComponent("main-repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init"], in: repoDir)

        XCTAssertNil(GitOperations.mainRepositoryPath(for: repoDir.path))
    }

    func testMainRepositoryPathResolvesWorktreeToMainRepo() throws {
        let repoDir = tempDir.appendingPathComponent("main-repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let worktreeDir = tempDir.appendingPathComponent("worktree-branch")
        git(["worktree", "add", "-b", "test-branch", worktreeDir.path], in: repoDir)

        let result = GitOperations.mainRepositoryPath(for: worktreeDir.path)
        XCTAssertEqual(
            URL(fileURLWithPath: result ?? "").standardizedFileURL.path,
            repoDir.standardizedFileURL.path
        )
    }

    func testMainRepositoryPathReturnsNilForNestedDirectoryInWorktree() throws {
        let repoDir = tempDir.appendingPathComponent("main-repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let worktreeDir = tempDir.appendingPathComponent("worktree-branch")
        git(["worktree", "add", "-b", "test-branch", worktreeDir.path], in: repoDir)

        // A subdirectory inside the worktree doesn't have its own .git file
        let subDir = worktreeDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        XCTAssertNil(GitOperations.mainRepositoryPath(for: subDir.path))
    }

    // MARK: - defaultBranch

    func testDefaultBranchReturnsLocalMainWhenNoRemote() throws {
        let repoDir = tempDir.appendingPathComponent("no-remote")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let branch = GitOperations.defaultBranch(at: repoDir.path)
        XCTAssertEqual(branch, "main")
    }

    func testDefaultBranchReturnsMasterWhenNoMainBranch() throws {
        let repoDir = tempDir.appendingPathComponent("master-repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "master"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let branch = GitOperations.defaultBranch(at: repoDir.path)
        XCTAssertEqual(branch, "master")
    }

    func testDefaultBranchReturnsHEADWhenNeitherMainNorMasterExist() throws {
        let repoDir = tempDir.appendingPathComponent("custom-branch")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "develop"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let branch = GitOperations.defaultBranch(at: repoDir.path)
        XCTAssertEqual(branch, "HEAD")
    }

    func testDefaultBranchPrefersOriginOverLocal() throws {
        // Create a non-bare "remote" repo with a commit on main
        let remoteDir = tempDir.appendingPathComponent("remote")
        try FileManager.default.createDirectory(at: remoteDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: remoteDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: remoteDir)

        // Clone it so we have origin/main
        let repoDir = tempDir.appendingPathComponent("cloned")
        git(["clone", remoteDir.path, repoDir.path], in: tempDir)

        let branch = GitOperations.defaultBranch(at: repoDir.path)
        XCTAssertTrue(branch.contains("origin"), "Expected origin-prefixed branch, got: \(branch)")
    }

    // MARK: - fetchDefaultBranch

    func testFetchDefaultBranchDoesNotCrashWithoutRemote() throws {
        let repoDir = tempDir.appendingPathComponent("no-remote-fetch")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        // Should return silently without crashing
        GitOperations.fetchDefaultBranch(at: repoDir.path)
    }

    func testFetchDefaultBranchDoesNotCrashForNonGitDirectory() throws {
        let plainDir = tempDir.appendingPathComponent("not-a-repo")
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        // Should return silently without crashing
        GitOperations.fetchDefaultBranch(at: plainDir.path)
    }

    func testFetchDefaultBranchDoesNotCrashWithUnreachableRemote() throws {
        let repoDir = tempDir.appendingPathComponent("bad-remote")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)
        git(["remote", "add", "origin", "https://invalid.example.com/repo.git"], in: repoDir)

        // Should fail silently (timeout or network error)
        GitOperations.fetchDefaultBranch(at: repoDir.path)
    }

    // MARK: - currentBranch

    func testCurrentBranchReturnsActiveBranch() throws {
        let repoDir = tempDir.appendingPathComponent("branch-test")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        XCTAssertEqual(GitOperations.currentBranch(at: repoDir.path), "main")
    }

    func testCurrentBranchReturnsNilForNonGitDirectory() throws {
        let plainDir = tempDir.appendingPathComponent("not-a-repo")
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        XCTAssertNil(GitOperations.currentBranch(at: plainDir.path))
    }

    func testCurrentBranchReturnsWorktreeBranch() throws {
        let repoDir = tempDir.appendingPathComponent("main-repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let worktreeDir = tempDir.appendingPathComponent("wt")
        git(["worktree", "add", "-b", "ff/my-feature", worktreeDir.path], in: repoDir)

        XCTAssertEqual(GitOperations.currentBranch(at: worktreeDir.path), "ff/my-feature")
    }

    // MARK: - deleteLocalBranch

    func testDeleteLocalBranchRemovesBranch() throws {
        let repoDir = tempDir.appendingPathComponent("delete-branch")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)
        git(["branch", "feature"], in: repoDir)

        GitOperations.deleteLocalBranch(at: repoDir.path, branchName: "feature")

        // Verify branch no longer exists
        let result = git(["rev-parse", "--verify", "refs/heads/feature"], in: repoDir)
        XCTAssertFalse(result, "Branch should have been deleted")
    }

    // MARK: - fetchDefaultBranch

    func testFetchDefaultBranchSkipsWithoutRemote() throws {
        let repoDir = tempDir.appendingPathComponent("no-remote-update")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        // Should return silently without crashing
        GitOperations.fetchDefaultBranch(at: repoDir.path)
    }

    func testFetchDefaultBranchDoesNotMoveLocalRef() throws {
        // Create a "remote" repo
        let remoteDir = tempDir.appendingPathComponent("remote")
        try FileManager.default.createDirectory(at: remoteDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: remoteDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: remoteDir)

        // Clone it
        let repoDir = tempDir.appendingPathComponent("local")
        git(["clone", remoteDir.path, repoDir.path], in: tempDir)

        // Record the initial commit
        let beforeSHA = gitOutput(["rev-parse", "refs/heads/main"], in: repoDir)

        // Add a new commit to remote
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "second"], in: remoteDir)

        // Fetch should update remote tracking ref but not local main
        GitOperations.fetchDefaultBranch(at: repoDir.path)

        let afterSHA = gitOutput(["rev-parse", "refs/heads/main"], in: repoDir)
        XCTAssertEqual(beforeSHA, afterSHA, "Local main should not have moved")

        let remoteSHA = gitOutput(["rev-parse", "refs/remotes/origin/main"], in: repoDir)
        XCTAssertNotEqual(beforeSHA, remoteSHA, "Remote tracking ref should have advanced")
    }

    // MARK: - fileStatuses

    func testFileStatusesReturnsModifiedForTrackedChanges() throws {
        let repoDir = tempDir.appendingPathComponent("status-modified")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)

        let filePath = repoDir.appendingPathComponent("tracked.txt")
        try "original".write(to: filePath, atomically: true, encoding: .utf8)
        git(["add", "tracked.txt"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "-m", "init"], in: repoDir)

        try "changed".write(to: filePath, atomically: true, encoding: .utf8)

        let statuses = GitOperations.fileStatuses(at: repoDir.path)
        XCTAssertEqual(statuses["tracked.txt"], .modified)
    }

    func testFileStatusesReturnsUntrackedForNewFiles() throws {
        let repoDir = tempDir.appendingPathComponent("status-untracked")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        try "new file".write(
            to: repoDir.appendingPathComponent("untracked.txt"),
            atomically: true, encoding: .utf8
        )

        let statuses = GitOperations.fileStatuses(at: repoDir.path)
        XCTAssertEqual(statuses["untracked.txt"], .untracked)
    }

    func testFileStatusesReturnsIgnoredForGitignored() throws {
        let repoDir = tempDir.appendingPathComponent("status-ignored")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)

        try "build/\n".write(
            to: repoDir.appendingPathComponent(".gitignore"),
            atomically: true, encoding: .utf8
        )
        let buildDir = repoDir.appendingPathComponent("build")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try "artifact".write(
            to: buildDir.appendingPathComponent("output.o"),
            atomically: true, encoding: .utf8
        )

        let statuses = GitOperations.fileStatuses(at: repoDir.path)
        XCTAssertEqual(statuses["build"], .ignored)
    }

    func testFileStatusesReturnsEmptyForNonGitDirectory() throws {
        let plainDir = tempDir.appendingPathComponent("no-git")
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        let statuses = GitOperations.fileStatuses(at: plainDir.path)
        XCTAssertTrue(statuses.isEmpty)
    }

    func testFileStatusesHandlesRenames() throws {
        let repoDir = tempDir.appendingPathComponent("status-rename")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)

        try "content".write(
            to: repoDir.appendingPathComponent("old.txt"),
            atomically: true, encoding: .utf8
        )
        git(["add", "old.txt"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "-m", "init"], in: repoDir)

        git(["mv", "old.txt", "new.txt"], in: repoDir)

        let statuses = GitOperations.fileStatuses(at: repoDir.path)
        XCTAssertEqual(statuses["new.txt"], .modified)
    }

    // MARK: - pruneCleanWorktrees

    func testPruneCleanWorktreesPrunesOnlyRequestedPaths() throws {
        let repoDir = tempDir.appendingPathComponent("prune-filtered")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        git(["init", "-b", "main"], in: repoDir)
        git(["-c", "user.email=test@test.com", "-c", "user.name=Test",
             "commit", "--allow-empty", "-m", "init"], in: repoDir)

        let worktreeA = tempDir.appendingPathComponent("worktree-a")
        let worktreeB = tempDir.appendingPathComponent("worktree-b")
        XCTAssertTrue(git(["worktree", "add", "-b", "feature/a", worktreeA.path], in: repoDir))
        XCTAssertTrue(git(["worktree", "add", "-b", "feature/b", worktreeB.path], in: repoDir))

        let pruned = GitOperations.pruneCleanWorktrees(
            at: repoDir.path,
            onlyPaths: Set([worktreeA.path])
        )

        XCTAssertEqual(pruned, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: worktreeA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeB.path))
    }

    // MARK: - Helpers

    @discardableResult
    private func git(_ args: [String], in dir: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func gitOutput(_ args: [String], in dir: URL) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
