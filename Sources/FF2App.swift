// ABOUTME: Main application entry point.
// ABOUTME: Initializes the ghostty terminal engine and presents the main window.

import Sentry
import Sparkle
import SwiftUI

extension Notification.Name {
    static let openDirectory = Notification.Name("factoryfloor.openDirectory")
    static let openSettings = Notification.Name("factoryfloor.openSettings")
    static let openHelp = Notification.Name("factoryfloor.openHelp")
    static let switchToProject = Notification.Name("factoryfloor.switchToProject")
    static let toggleSidebar = Notification.Name("factoryfloor.toggleSidebar")
    static let switchByNumber = Notification.Name("factoryfloor.switchByNumber") // object: Int (1-9)
    static let dismissOverlay = Notification.Name("factoryfloor.dismissOverlay")
    static let openExternalBrowser = Notification.Name("factoryfloor.openExternalBrowser")
    static let clearProjects = Notification.Name("factoryfloor.clearProjects")
    static let openExternalTerminal = Notification.Name("factoryfloor.openExternalTerminal")
    static let switchToWorkstream = Notification.Name("factoryfloor.switchToWorkstream")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        let confirmQuit = UserDefaults.standard.object(forKey: "factoryfloor.confirmQuit") as? Bool ?? true
        guard confirmQuit else { return .terminateNow }
        let projects = ProjectStore.load()
        let hasWorkstreams = projects.contains { !$0.workstreams.isEmpty }
        guard hasWorkstreams else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Quit Factory Floor?", comment: "")
        alert.informativeText = NSLocalizedString("Active workstreams will be stopped.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct FF2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updater = Updater()
    @State private var pendingURLDirectory: String?

    init() {
        SentrySDK.start { options in
            options.dsn = "https://45310bb703b438b38aee17e84e10d32e@o4511060356956160.ingest.de.sentry.io/4511060370391120"
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 5
            options.sendDefaultPii = false
            options.releaseName = "\(AppConstants.appID)@\(AppConstants.version)"
            #if DEBUG
                options.environment = "development"
            #else
                options.environment = "production"
            #endif
        }

        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Factory Floor cannot start", comment: "")
            alert.informativeText = NSLocalizedString(
                "The terminal engine (Ghostty) failed to initialize. This may indicate a system compatibility issue.",
                comment: ""
            )
            alert.alertStyle = .critical
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
            alert.runModal()
            exit(1)
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
                .environmentObject(updater)
                .onAppear {
                    if let dir = Self.launchDirectory {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .openDirectory, object: dir)
                        }
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == AppConstants.urlScheme else { return }
                    let path = url.path
                    guard !path.isEmpty else { return }
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
                    pendingURLDirectory = path
                }
                .alert(
                    Text("Open Directory"),
                    isPresented: Binding(
                        get: { pendingURLDirectory != nil },
                        set: { if !$0 { pendingURLDirectory = nil } }
                    )
                ) {
                    Button("Allow") {
                        if let path = pendingURLDirectory {
                            NotificationCenter.default.post(name: .openDirectory, object: path)
                        }
                        pendingURLDirectory = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingURLDirectory = nil
                    }
                } message: {
                    Text("An external application wants to open \(pendingURLDirectory ?? "") in \(AppConstants.appName).")
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Remove the default Help menu so Cmd+Shift+/ doesn't open it
            CommandGroup(replacing: .help) {}

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
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

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

                Button("Environment") {
                    NotificationCenter.default.post(name: .toggleEnvironment, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Rebuild Setup") {
                    NotificationCenter.default.post(name: .rebuildSetup, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.control, .shift])

                Button("Start/Rerun") {
                    NotificationCenter.default.post(name: .rerunScript, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.control, .shift])

                Divider()

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
                ForEach(1 ... 9, id: \.self) { n in
                    Button("Switch to Tab \(n)") { NotificationCenter.default.post(name: .switchByNumber, object: n) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                }
                ForEach(1 ... 9, id: \.self) { n in
                    Button("Switch to Workstream \(n)") { NotificationCenter.default.post(name: .switchToWorkstream, object: n) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .control)
                }
            }
        }
    }
}
