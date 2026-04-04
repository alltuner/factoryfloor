// ABOUTME: Extension on NSAppearance to detect dark mode.
// ABOUTME: Used to sync the terminal color scheme with the system appearance.

import Cocoa

extension NSAppearance {
    var isDark: Bool {
        name.rawValue.lowercased().contains("dark")
    }
}
