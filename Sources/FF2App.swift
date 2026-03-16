// ABOUTME: Main application entry point.
// ABOUTME: Initializes the ghostty terminal engine and presents the main window.

import SwiftUI

extension Notification.Name {
    static let openDirectory = Notification.Name("factoryfloor.openDirectory")
    static let openSettings = Notification.Name("factoryfloor.openSettings")
    static let openHelp = Notification.Name("factoryfloor.openHelp")
    static let retryBrowser = Notification.Name("factoryfloor.retryBrowser")
    static let switchToProject = Notification.Name("factoryfloor.switchToProject")
    static let toggleSidebar = Notification.Name("factoryfloor.toggleSidebar")
    static let switchByNumber = Notification.Name("factoryfloor.switchByNumber") // object: Int (1-9)
    // switchToInfo, switchToAgent, switchToTerminal replaced by switchByNumber
    static let dismissOverlay = Notification.Name("factoryfloor.dismissOverlay")
    static let openExternalBrowser = Notification.Name("factoryfloor.openExternalBrowser")
    static let clearProjects = Notification.Name("factoryfloor.clearProjects")
    static let openExternalTerminal = Notification.Name("factoryfloor.openExternalTerminal")
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
        Window(AppConstants.appName, id: "main") {
            ContentView()
                .onAppear {
                    if let dir = Self.launchDirectory {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .openDirectory, object: dir)
                        }
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == AppConstants.appID else { return }
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

                Button("Help") {
                    NotificationCenter.default.post(name: .openHelp, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }
            // View menu
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Divider()

                Button("Toggle Info") {
                    NotificationCenter.default.post(name: .toggleInfo, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Toggle Terminal") {
                    NotificationCenter.default.post(name: .toggleTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Toggle Browser") {
                    NotificationCenter.default.post(name: .toggleBrowser, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Next Tab") {
                    NotificationCenter.default.post(name: .nextTab, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: .prevTab, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Address Bar") {
                    NotificationCenter.default.post(name: .focusAddressBar, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Focus Agent") {
                    NotificationCenter.default.post(name: .focusAgent, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Open in External Browser") {
                    NotificationCenter.default.post(name: .openExternalBrowser, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Open in External Terminal") {
                    NotificationCenter.default.post(name: .openExternalTerminal, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            // Contextual shortcuts (in menu but minimal labels)
            CommandGroup(after: .toolbar) {
                Button("Back to Project") { NotificationCenter.default.post(name: .switchToProject, object: nil) }
                    .keyboardShortcut("0", modifiers: .command)
                ForEach(1...9, id: \.self) { n in
                    Button("Switch to \(n)") { NotificationCenter.default.post(name: .switchByNumber, object: n) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                }
            }
        }
    }
}
