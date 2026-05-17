// ABOUTME: Checks the local repository for updates against origin/main.
// ABOUTME: Provides a function to launch Terminal and pull/rebuild the app.

import Combine
import Foundation
import OSLog
import AppKit

private let logger = Logger(subsystem: "dockyard", category: "appUpdater")

@MainActor
final class AppUpdater: ObservableObject {
    @Published var commitsAhead: Int = 0
    @Published var isChecking: Bool = false

    private var updateTask: Task<Void, Never>?

    init() {
        // Initial check
        checkForUpdates()

        // Periodic check every 15 minutes
        updateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900 * 1_000_000_000)
                if Task.isCancelled { break }
                self?.checkForUpdates()
            }
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true

        Task.detached {
            let path = AppCommit.sourcePath
            
            // 1. Fetch from origin main
            let fetchProcess = Process()
            fetchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            fetchProcess.arguments = ["fetch", "origin", "main"]
            fetchProcess.currentDirectoryURL = URL(fileURLWithPath: path)
            try? fetchProcess.run()
            fetchProcess.waitUntilExit()

            // 2. Count commits
            let countProcess = Process()
            countProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            countProcess.arguments = ["rev-list", "--count", "HEAD..origin/main"]
            countProcess.currentDirectoryURL = URL(fileURLWithPath: path)

            let pipe = Pipe()
            countProcess.standardOutput = pipe

            do {
                try countProcess.run()
                countProcess.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let count = Int(output) {
                    await MainActor.run {
                        self.commitsAhead = count
                        self.isChecking = false
                    }
                } else {
                    await MainActor.run {
                        self.isChecking = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isChecking = false
                }
            }
        }
    }

    func applyUpdate() {
        let path = AppCommit.sourcePath
        let isDebug = AppCommit.configuration == "Debug"
        
        // If Debug, we build but maybe we shouldn't kill if we don't want to lose state?
        // But debug usually runs out of Xcode or derived data, so `br` kills it.
        // For Release (what the user runs), use install-bg so we don't interrupt them.
        let buildScript = isDebug ? "./scripts/dev.sh br" : "./scripts/dev.sh install-bg"

        // Create an AppleScript to open Terminal and run the commands
        let scriptSource = """
        tell application "Terminal"
            activate
            do script "cd '\(path)' && echo 'Pulling latest changes...' && git pull origin main && echo 'Building Dockyard...' && \(buildScript) && echo 'Update complete. Restart the app when ready.'"
        end tell
        """

        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            if let errorInfo = errorInfo {
                logger.error("Failed to execute AppleScript for update: \(errorInfo.description)")
            }
        }
    }
}
