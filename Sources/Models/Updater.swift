// ABOUTME: Sparkle-based auto-update controller for DMG-distributed builds.
// ABOUTME: Provides check-for-updates action wired to the app menu.

import Sparkle

@MainActor
final class Updater: ObservableObject {
    private var controller: SPUStandardUpdaterController?

    init() {
        #if !DEBUG
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        #endif
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
