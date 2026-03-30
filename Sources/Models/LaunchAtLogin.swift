// ABOUTME: Manages the app's launch-at-login registration via SMAppService.
// ABOUTME: Provides a simple enable/disable interface backed by the system login item service.

import OSLog
import ServiceManagement

enum LaunchAtLogin {
    private static let logger = Logger(subsystem: AppConstants.appID, category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered launch at login")
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
        }
    }
}
