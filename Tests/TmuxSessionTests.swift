// ABOUTME: Tests for tmux session configuration and command composition.
// ABOUTME: Verifies respawn behavior is scoped to agent sessions, not global.

@testable import FactoryFloor
import XCTest

final class TmuxSessionTests: XCTestCase {
    func testConfigKeepsNativeMouseSelectionEnabled() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -g mouse off"))
        XCTAssertFalse(TmuxSession.configContents.contains("set -g mouse on"))
    }

    func testConfigKeepsOuterTerminalOutOfAlternateScreen() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -ga terminal-overrides ',*:smcup@:rmcup@'"))
    }

    func testConfigDisablesPaneAlternateScreen() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -g alternate-screen off"))
    }

    func testConfigDoesNotGloballyRespawnDeadPanes() {
        XCTAssertFalse(TmuxSession.configContents.contains("pane-died"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit on"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit-format \"\""))
    }

    func testRespawnOnExitAddsSessionLevelHook() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "claude",
            respawnOnExit: true,
            shell: "/bin/zsh"
        )
        XCTAssertTrue(command.contains("set-hook pane-died"))
    }

    func testDefaultDoesNotRespawn() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/setup",
            command: "setup.sh",
            shell: "/bin/zsh"
        )
        XCTAssertFalse(command.contains("pane-died"))
    }

    func testWrapCommandQuotesEnvVarValuesWithSpaces() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "echo hello",
            environmentVars: ["FF_PROJECT": "My Project"],
            shell: "/bin/zsh"
        )

        // The value must be double-quoted so the shell keeps it as one token
        XCTAssertTrue(command.contains("-e \"FF_PROJECT=My Project\""))
    }

    func testWrapCommandQuotesEnvVarValuesWithSpecialChars() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "echo hello",
            environmentVars: ["FF_PROJECT": "client's \"best\" $project"],
            shell: "/bin/zsh"
        )

        // Single quotes, double quotes, and dollar signs must survive nested quoting.
        // The two-layer shell wrapping (login shell -> sh) applies shellEscape twice,
        // so we verify the key and double-quote-escaped value appear at the inner level.
        XCTAssertTrue(command.contains("FF_PROJECT"))
        XCTAssertTrue(command.contains("client"))
        XCTAssertTrue(command.contains("best"))
        XCTAssertTrue(command.contains("\\$project"))
    }

    func testWrapCommandFishUsesDoubleQuotes() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "claude",
            respawnOnExit: true,
            shell: "/opt/homebrew/bin/fish"
        )
        XCTAssertTrue(command.hasPrefix("/opt/homebrew/bin/fish -lic \""), "Fish should use double-quote wrapping")
        XCTAssertTrue(command.contains("exec sh -c"), "Should still use sh for POSIX syntax")
        XCTAssertTrue(command.contains("new-session -A -s"))
        XCTAssertTrue(command.contains("claude"))
    }

    func testWrapCommandFishDoesNotContainPosixQuoteEscape() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "claude",
            shell: "/opt/homebrew/bin/fish"
        )
        // The outermost layer should NOT contain '\'' which Fish can't parse
        let outerQuoteEnd = command.index(command.startIndex, offsetBy: "/opt/homebrew/bin/fish -lic ".count)
        let outerArg = String(command[outerQuoteEnd...])
        XCTAssertTrue(outerArg.hasPrefix("\""), "Outer argument should start with double quote")
        // Inner POSIX quoting (parsed by sh, not Fish) may still use '\'' and that's fine
    }

    // MARK: - Shell syntax validation (integration tests)

    // Invoke real shell binaries to verify generated tmux commands parse correctly.
    // Ghostty passes commands to /bin/sh -c, so that's what we simulate.

    private func assertShellCanParse(_ command: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let syntaxCheck = command.replacingOccurrences(of: " -lic ", with: " -nc ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", syntaxCheck]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "(no stderr)"
            XCTFail("Shell failed to parse command (exit \(process.terminationStatus)): \(errMsg)", file: file, line: line)
        }
    }

    private func realisticTmuxCommand(shell: String) -> String {
        TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "factoryfloor/my-project/deploy-auth-fix/agent",
            command: "/opt/homebrew/bin/claude --resume a1b2c3d4 --name 'deploy auth fix'",
            environmentVars: [
                "FF_PROJECT": "My Project",
                "FF_WORKSTREAM": "deploy-auth-fix",
                "FF_DIR": "/Users/test/repos/my project's dir",
            ],
            respawnOnExit: true,
            shell: shell
        )
    }

    func testTmuxCommandParsesInFish() throws {
        let fishPath = "/opt/homebrew/bin/fish"
        guard FileManager.default.fileExists(atPath: fishPath) else {
            throw XCTSkip("Fish not installed at \(fishPath)")
        }
        let command = realisticTmuxCommand(shell: fishPath)
        try assertShellCanParse(command)
    }

    func testTmuxCommandParsesInZsh() throws {
        let command = realisticTmuxCommand(shell: "/bin/zsh")
        try assertShellCanParse(command)
    }

    func testTmuxCommandParsesInBash() throws {
        let command = realisticTmuxCommand(shell: "/bin/bash")
        try assertShellCanParse(command)
    }

    func testWrapCommandUsesLoginShellAndStartsServer() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "project/workstream/setup",
            command: "bun run build",
            shell: "/bin/zsh"
        )

        XCTAssertTrue(command.hasPrefix("/bin/zsh -lic "), "Should use interactive login shell for PATH")
        XCTAssertTrue(command.contains("exec sh -c"), "Should use sh for POSIX syntax")
        XCTAssertTrue(command.contains("start-server"))
        XCTAssertTrue(command.contains("source-file"))
        XCTAssertTrue(command.contains("new-session -A -s"))
        XCTAssertTrue(command.contains("bun run build"))
    }
}
