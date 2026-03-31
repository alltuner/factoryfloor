// ABOUTME: Sparkle-based auto-update controller for DMG-distributed builds.
// ABOUTME: Provides check-for-updates action wired to the app menu.

import Sparkle

/// Suppresses modal error alerts from Sparkle update checks.
/// Errors (e.g. network failures) are silently acknowledged instead of
/// blocking the main thread with NSAlert.runModal(). (Fixes FACTORY-FLOOR-7)
private class SilentErrorUserDriver: SPUStandardUserDriver {
    override func showUpdaterError(_: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }
}

@MainActor
final class Updater: ObservableObject {
    private var updater: SPUUpdater?

    init() {
        #if !DEBUG
            let userDriver = SilentErrorUserDriver(hostBundle: .main, delegate: nil)
            do {
                let spuUpdater = try SPUUpdater(
                    hostBundle: .main,
                    applicationBundle: .main,
                    userDriver: userDriver,
                    delegate: nil
                )
                try spuUpdater.start()
                updater = spuUpdater
            } catch {
                // Sparkle failed to initialize; updates won't be available
            }
        #endif
    }

    var canCheckForUpdates: Bool {
        updater?.canCheckForUpdates ?? false
    }

    /// Whether Sparkle was successfully initialized (DMG installs).
    /// Unlike `canCheckForUpdates`, this doesn't depend on transient Sparkle state.
    var isConfigured: Bool {
        updater != nil
    }

    func checkForUpdates() {
        updater?.checkForUpdates()
    }
}
