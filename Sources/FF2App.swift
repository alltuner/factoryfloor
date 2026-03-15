// ABOUTME: Main application entry point.
// ABOUTME: Initializes the ghostty terminal engine and presents the main window.

import SwiftUI

extension Notification.Name {
    static let openDirectory = Notification.Name("ff2.openDirectory")
    static let openSettings = Notification.Name("ff2.openSettings")
    static let retryBrowser = Notification.Name("ff2.retryBrowser")
    static let switchToProject = Notification.Name("ff2.switchToProject")
    static let switchToInfo = Notification.Name("ff2.switchToInfo")
    static let switchToAgent = Notification.Name("ff2.switchToAgent")
    static let switchToTerminal = Notification.Name("ff2.switchToTerminal")
    static let openExternalBrowser = Notification.Name("ff2.openExternalBrowser")
    static let clearProjects = Notification.Name("ff2.clearProjects")
    static let openExternalTerminal = Notification.Name("ff2.openExternalTerminal")
    static let nextTab = Notification.Name("ff2.nextTab")
    static let prevTab = Notification.Name("ff2.prevTab")
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
            // Cmd+0: project view, Cmd+1-4: workstream tabs
            CommandGroup(after: .toolbar) {
                Button("Project") {
                    NotificationCenter.default.post(name: .switchToProject, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Info") {
                    NotificationCenter.default.post(name: .switchToInfo, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Coding Agent") {
                    NotificationCenter.default.post(name: .switchToAgent, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Terminal") {
                    NotificationCenter.default.post(name: .switchToTerminal, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Browser") {
                    NotificationCenter.default.post(name: .retryBrowser, object: nil)
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("Open in External Browser") {
                    NotificationCenter.default.post(name: .openExternalBrowser, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Open in External Terminal") {
                    NotificationCenter.default.post(name: .openExternalTerminal, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Next Tab") {
                    NotificationCenter.default.post(name: .nextTab, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: .prevTab, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            }
        }
    }
}
