// ABOUTME: Singleton that owns the ghostty_app_t lifecycle and runtime callbacks.
// ABOUTME: All terminal surfaces are created through this app instance.

import Cocoa
import os

private let logger = Logger(subsystem: "factoryfloor", category: "terminal-app")

@MainActor
final class TerminalApp {
    static let shared = TerminalApp()

    nonisolated(unsafe) private(set) var app: ghostty_app_t?

    private init() {
        // Create config
        guard let config = ghostty_config_new() else {
            logger.error("ghostty_config_new failed")
            return
        }
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Create runtime config with callbacks
        var runtimeConfig = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { userdata in
                guard let userdata else { return }
                let app = Unmanaged<TerminalApp>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        app.tick()
                    }
                }
            },
            action_cb: { _, target, action in
                MainActor.assumeIsolated {
                    guard target.tag == GHOSTTY_TARGET_SURFACE else { return false }
                    switch action.tag {
                    case GHOSTTY_ACTION_SET_TITLE:
                        guard let cstr = action.action.set_title.title else { return false }
                        let title = String(cString: cstr)
                        guard let view = TerminalView.view(for: target.target.surface),
                              let wsID = view.workstreamID else { return false }
                        NotificationCenter.default.post(
                            name: .terminalTitleChanged,
                            object: wsID,
                            userInfo: ["title": title]
                        )
                        return true
                    default:
                        return false
                    }
                }
            },
            read_clipboard_cb: { userdata, location, state in
                guard let userdata else { return false }
                guard let state else { return false }

                let performRead = {
                    let pasteboard = NSPasteboard.general
                    guard let str = pasteboard.string(forType: .string) else { return false }

                    let surfaceView = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()
                    guard let surface = surfaceView.surface else { return false }
                    str.withCString { cstr in
                        ghostty_surface_complete_clipboard_request(surface, cstr, state, true)
                    }
                    return true
                }
                if Thread.isMainThread {
                    return MainActor.assumeIsolated { performRead() }
                }
                return DispatchQueue.main.sync {
                    MainActor.assumeIsolated { performRead() }
                }
            },
            confirm_read_clipboard_cb: nil,
            write_clipboard_cb: { userdata, location, content, len, confirm in
                guard let content, len > 0 else { return }

                let performWrite = {
                    // Find the text/plain entry
                    for i in 0..<len {
                        let item = content[i]
                        guard let mime = item.mime, let data = item.data else { continue }
                        let mimeStr = String(cString: mime)
                        if mimeStr == "text/plain" {
                            let str = String(cString: data)
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(str, forType: .string)
                            break
                        }
                    }
                }
                if Thread.isMainThread {
                    MainActor.assumeIsolated { performWrite() }
                } else {
                    DispatchQueue.main.sync {
                        MainActor.assumeIsolated { performWrite() }
                    }
                }
            },
            close_surface_cb: { userdata, processAlive in
                guard let userdata else { return }
                let surfaceView = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        surfaceView.surfaceClosed()
                    }
                }
            }
        )

        guard let app = ghostty_app_new(&runtimeConfig, config) else {
            logger.error("ghostty_app_new failed")
            ghostty_config_free(config)
            return
        }
        self.app = app
        ghostty_config_free(config)

        // Defer focus setup until NSApp exists
        DispatchQueue.main.async { [weak self] in
            guard let self, let app = self.app else { return }
            if let nsApp = NSApp {
                ghostty_app_set_focus(app, nsApp.isActive)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let app = self?.app else { return }
            ghostty_app_set_focus(app, true)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let app = self?.app else { return }
            ghostty_app_set_focus(app, false)
        }
    }

    private func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    deinit {
        if let app {
            ghostty_app_free(app)
        }
    }
}
