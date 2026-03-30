// ABOUTME: Extension on os.Logger for debug logging gated on the detailedLogging user preference.
// ABOUTME: Reads the UserDefaults flag so verbose logs appear in Console.app only when enabled.

import Foundation
import os

extension Logger {
    /// Log a debug message only when the user has enabled detailed logging in settings.
    /// This lets users opt-in to verbose diagnostics without needing to configure Console.app filters.
    func detailed(_ message: String) {
        guard UserDefaults.standard.bool(forKey: "factoryfloor.detailedLogging") else { return }
        debug("\(message, privacy: .public)")
    }
}
