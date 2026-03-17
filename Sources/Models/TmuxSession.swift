// ABOUTME: Tmux session naming and command wrapping for persistent sessions.
// ABOUTME: Sessions survive app restarts but not system restarts.

import Foundation

enum TmuxSession {
    /// Build a deterministic session name from project, workstream, and role.
    static func sessionName(project: String, workstream: String, role: String) -> String {
        "\(AppConstants.appID)/\(sanitize(project))/\(sanitize(workstream))/\(role)"
    }

    /// Path to the minimal tmux config that makes tmux invisible.
    private static var configPath: String {
        let path = AppConstants.configDirectory.appendingPathComponent("tmux.conf")
        let config = """
        # Managed by \(AppConstants.appID). Do not edit.
        # Makes tmux act as a transparent session persistence wrapper.
        set -g status off
        set -g prefix None
        unbind-key -a
        set -g mouse on
        # Disable mouse drag for selection (let ghostty handle it)
        unbind -n MouseDrag1Pane
        set -g history-limit 50000
        set -g escape-time 0
        set -g allow-passthrough on
        set -g default-terminal "xterm-256color"
        set -g aggressive-resize on
        set -g window-size latest
        set -g remain-on-exit on
        set-hook -g pane-died 'respawn-pane'
        """
        // Write config if missing or outdated
        let fm = FileManager.default
        try? fm.createDirectory(at: AppConstants.configDirectory, withIntermediateDirectories: true)
        if let existing = try? String(contentsOfFile: path.path, encoding: .utf8), existing == config {
            return path.path
        }
        try? config.write(toFile: path.path, atomically: true, encoding: .utf8)
        return path.path
    }

    /// Wrap a command to run inside a tmux session.
    /// Uses `new-session -A` which creates if missing, attaches if existing.
    /// Tmux is configured to be invisible: no status bar, no prefix key,
    /// mouse passthrough for scrolling.
    /// Dedicated socket name so we don't interfere with the user's tmux.
    private static let socketName = AppConstants.appID

    static func wrapCommand(tmuxPath: String, sessionName: String, command: String?) -> String {
        let escaped = shellEscape(sessionName)
        let conf = shellEscape(configPath)
        // -L uses a dedicated socket, -f uses our minimal config
        let base = "\(tmuxPath) -L \(socketName) -f \(conf) new-session -A -s \(escaped)"
        if let command {
            let escapedCommand = shellEscape(command)
            return "\(base) -- sh -c \(escapedCommand)"
        }
        return base
    }

    /// Kill a tmux session by name.
    static func killSession(tmuxPath: String, sessionName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmuxPath)
        process.arguments = ["-L", socketName, "kill-session", "-t", sessionName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Kill the agent tmux session for a workstream.
    static func killWorkstreamSessions(tmuxPath: String, project: String, workstream: String) {
        let agentSession = sessionName(project: project, workstream: workstream, role: "agent")
        killSession(tmuxPath: tmuxPath, sessionName: agentSession)
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private static func shellEscape(_ str: String) -> String {
        "'\(str.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
