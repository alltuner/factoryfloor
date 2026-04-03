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
}
