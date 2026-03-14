// ABOUTME: Main application entry point.
// ABOUTME: Initializes the ghostty terminal engine and presents the main window.

import SwiftUI

extension Notification.Name {
    static let openDirectory = Notification.Name("ff2.openDirectory")
    static let openSettings = Notification.Name("ff2.openSettings")
}

@main
struct FF2App: App {
    init() {
        // ghostty_init must happen before any ghostty API calls, but it's fast.
        // TerminalApp.shared is lazy and deferred to first access (when a terminal is needed).
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            fatalError("ghostty_init failed")
        }
    }

    /// Resolve the directory from CLI arguments.
    /// Only returns a path when an explicit argument is provided.
    /// Returns nil if no argument, or the path doesn't exist or isn't a directory.
    private static var launchDirectory: String? {
        guard CommandLine.arguments.count > 1 else { return nil }

        let resolved = NSString(string: CommandLine.arguments[1]).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return resolved
    }

    var body: some Scene {
        Window("ff2", id: "main") {
            ContentView()
                .onAppear {
                    if let dir = Self.launchDirectory {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .openDirectory, object: dir)
                        }
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == "ff2" else { return }
                    let path = url.path
                    guard !path.isEmpty else { return }
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
                    NotificationCenter.default.post(name: .openDirectory, object: path)
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Cmd+N: context-sensitive (add project if none selected, else add workstream)
                Button("New") {
                    NotificationCenter.default.post(name: .addNew, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                // Cmd+Shift+N: always add project
                Button("New Project") {
                    NotificationCenter.default.post(name: .addProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            // Cmd+,: toggle settings
            CommandGroup(after: .appSettings) {
                Button("Settings") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
