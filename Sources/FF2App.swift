// ABOUTME: Main application entry point.
// ABOUTME: Initializes the ghostty terminal engine and presents the main window.

import os
import Sentry
import Sparkle
import SwiftUI
import UserNotifications

private let logger = Logger(subsystem: "factoryfloor", category: "app")

protocol NotificationAuthorizationRequesting {
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    )
}

extension UNUserNotificationCenter: NotificationAuthorizationRequesting {}

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
    static let nextWorkstream = Notification.Name("factoryfloor.nextWorkstream")
    static let prevWorkstream = Notification.Name("factoryfloor.prevWorkstream")
    static let nextProject = Notification.Name("factoryfloor.nextProject")
    static let prevProject = Notification.Name("factoryfloor.prevProject")
    static let archiveWorkstream = Notification.Name("factoryfloor.archiveWorkstream")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    enum NotificationAuthorizationLogLevel {
        case info
        case warning
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard !isRunningXCTest() else { return }

        // Debug settings should not persist across launches
        UserDefaults.standard.set(false, forKey: "factoryfloor.quickActionDebug")

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Self.requestNotificationAuthorization(using: center)

        // Contextual shortcuts via key monitor (avoids cluttering the menu bar)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let chars = event.charactersIgnoringModifiers
            else { return event }
            if let digit = chars.first?.wholeNumberValue, (1 ... 9).contains(digit) {
                NotificationCenter.default.post(name: .switchByNumber, object: digit)
                return nil
            }
            if chars == "l" {
                NotificationCenter.default.post(name: .focusAddressBar, object: nil)
                return nil
            }
            return event
        }
    }

    nonisolated static func handleNotificationAuthorizationResult(
        granted: Bool,
        error: (any Error)?,
        log: @escaping @Sendable (String, NotificationAuthorizationLogLevel) -> Void = { message, level in
            switch level {
            case .info:
                logger.info("\(message, privacy: .public)")
            case .warning:
                logger.warning("\(message, privacy: .public)")
            }
        }
    ) {
        if Thread.isMainThread {
            if let error {
                log("Notification permission error: \(error.localizedDescription)", .warning)
            } else if !granted {
                log("Notification permission denied by user", .info)
            }
            return
        }

        Task { @MainActor in
            if let error {
                log("Notification permission error: \(error.localizedDescription)", .warning)
            } else if !granted {
                log("Notification permission denied by user", .info)
            }
        }
    }

    nonisolated static func requestNotificationAuthorization(
        using center: NotificationAuthorizationRequesting,
        log: @escaping @Sendable (String, NotificationAuthorizationLogLevel) -> Void = { message, level in
            switch level {
            case .info:
                logger.info("\(message, privacy: .public)")
            case .warning:
                logger.warning("\(message, privacy: .public)")
            }
        }
    ) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            handleNotificationAuthorizationResult(granted: granted, error: error, log: log)
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func applicationWillTerminate(_: Notification) {
        guard !isRunningXCTest() else { return }
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        let confirmQuit = UserDefaults.standard.object(forKey: "factoryfloor.confirmQuit") as? Bool ?? true
        guard confirmQuit else { return .terminateNow }
        let projects = ProjectStore.load()
        let hasWorkstreams = projects.contains { !$0.workstreams.isEmpty }
        guard hasWorkstreams else { return .terminateNow }
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Quit Factory Floor?", comment: "")
        alert.informativeText = NSLocalizedString("Active workstreams will be stopped.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        alert.beginSheetModal(for: window) { response in
            NSApp.reply(toApplicationShouldTerminate: response == .alertFirstButtonReturn)
        }
        return .terminateLater
    }
}

@main
struct FF2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updater = Updater()
    @AppStorage("factoryfloor.editorTabActive") private var isEditorActive = false
    @AppStorage("factoryfloor.editorFileDirty") private var isEditorDirty = false
    @State private var pendingURLDirectory: String?

    init() {
        guard !isRunningXCTest() else { return }

        let crashReportingEnabled = UserDefaults.standard.object(forKey: "factoryfloor.crashReportingEnabled") as? Bool ?? true
        if crashReportingEnabled {
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
            if isRunningXCTest() {
                EmptyView()
            } else {
                ContentView()
                    .environmentObject(updater)
                    .onAppear {
                        Telemetry.shared.trackLaunch()
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
            CommandGroup(replacing: .saveItem) {
                if isEditorActive {
                    Button("Save") {
                        NotificationCenter.default.post(name: .saveEditor, object: nil)
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!isEditorDirty)

                    Button("Save As...") {
                        NotificationCenter.default.post(name: .saveEditorAs, object: nil)
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                }
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
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
            // Tabs
            CommandGroup(after: .toolbar) {
                Button("Coding Agent") {
                    NotificationCenter.default.post(name: .focusAgent, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("New Terminal") {
                    NotificationCenter.default.post(name: .toggleTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Browser") {
                    NotificationCenter.default.post(name: .toggleBrowser, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("New Editor") {
                    NotificationCenter.default.post(name: .toggleEditor, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Start/Rerun") {
                    NotificationCenter.default.post(name: .rerunScript, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Divider()

                Button("Next Tab") {
                    NotificationCenter.default.post(name: .nextTab, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: .prevTab, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Back to Project") {
                    NotificationCenter.default.post(name: .switchToProject, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Next Workstream") {
                    NotificationCenter.default.post(name: .nextWorkstream, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Previous Workstream") {
                    NotificationCenter.default.post(name: .prevWorkstream, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Next Project") {
                    NotificationCenter.default.post(name: .nextProject, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Button("Previous Project") {
                    NotificationCenter.default.post(name: .prevProject, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Divider()

                Button("Open in External Browser") {
                    NotificationCenter.default.post(name: .openExternalBrowser, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])

                Button("Open in External Terminal") {
                    NotificationCenter.default.post(name: .openExternalTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Divider()

                Button("Archive Workstream") {
                    NotificationCenter.default.post(name: .archiveWorkstream, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
        }
    }
}
