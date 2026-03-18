// ABOUTME: Sparkle-based auto-update controller for DMG-distributed builds.
// ABOUTME: Provides check-for-updates action wired to the app menu.

import Sparkle

@MainActor
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
