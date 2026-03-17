// ABOUTME: Singleton that owns the ghostty_app_t lifecycle and runtime callbacks.
// ABOUTME: All terminal surfaces are created through this app instance.

import Cocoa
import os

private let logger = Logger(subsystem: "factoryfloor", category: "terminal-app")

private func handleTerminalWakeup(_ userdata: UnsafeMutableRawPointer?) {
    guard let userdata else { return }
    let userdataBits = UInt(bitPattern: userdata)
    DispatchQueue.main.async {
        let userdata = UnsafeMutableRawPointer(bitPattern: userdataBits)!
        let app = Unmanaged<TerminalApp>.fromOpaque(userdata).takeUnretainedValue()
        app.tick()
    }
}

private func handleTerminalAction(
    _ userdata: UnsafeMutableRawPointer?,
    _ target: ghostty_target_s,
    _ action: ghostty_action_s
) -> Bool {
    guard target.tag == GHOSTTY_TARGET_SURFACE else { return false }
    switch action.tag {
    case GHOSTTY_ACTION_SET_TITLE:
        guard let cstr = action.action.set_title.title else { return false }
        let title = String(cString: cstr)
        guard let view = TerminalView.view(for: target.target.surface),
              let wsID = view.workstreamID else { return false }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .terminalTitleChanged,
                object: wsID,
                userInfo: ["title": title]
            )
        }
        return true
    default:
        return false
    }
}

private func readTerminalClipboard(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ state: UnsafeMutableRawPointer?
) -> Bool {
    guard let userdata else { return false }
    guard let state else { return false }
    let userdataBits = UInt(bitPattern: userdata)
    let stateBits = UInt(bitPattern: state)

    if Thread.isMainThread {
        return completeClipboardRead(userdataBits: userdataBits, stateBits: stateBits)
    }
    return DispatchQueue.main.sync {
        completeClipboardRead(userdataBits: userdataBits, stateBits: stateBits)
    }
}

private func writeTerminalClipboard(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ content: UnsafePointer<ghostty_clipboard_content_s>?,
    _ len: Int,
    _ confirm: Bool
) {
    guard let content, len > 0 else { return }
    let entries = (0..<len).compactMap { index -> String? in
        let item = content[index]
        guard let mime = item.mime, let data = item.data else { return nil }
        let mimeStr = String(cString: mime)
        guard mimeStr == "text/plain" else { return nil }
        return String(cString: data)
    }
    guard let plainText = entries.first else { return }

    if Thread.isMainThread {
        writeClipboardText(plainText)
    } else {
        DispatchQueue.main.sync {
            writeClipboardText(plainText)
        }
    }
}

private func closeTerminalSurface(
    _ userdata: UnsafeMutableRawPointer?,
    _ processAlive: Bool
) {
    guard let userdata else { return }
    let userdataBits = UInt(bitPattern: userdata)
    DispatchQueue.main.async {
        let userdata = UnsafeMutableRawPointer(bitPattern: userdataBits)!
        let surfaceView = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()
        surfaceView.surfaceClosed()
    }
}

private func completeClipboardRead(userdataBits: UInt, stateBits: UInt) -> Bool {
    let pasteboard = NSPasteboard.general
    guard let str = pasteboard.string(forType: .string) else { return false }

    let userdata = UnsafeMutableRawPointer(bitPattern: userdataBits)!
    let state = UnsafeMutableRawPointer(bitPattern: stateBits)!
    let surfaceView = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()
    guard let surface = surfaceView.surface else { return false }
    str.withCString { cstr in
        ghostty_surface_complete_clipboard_request(surface, cstr, state, true)
    }
    return true
}

private func writeClipboardText(_ plainText: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(plainText, forType: .string)
}

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
            wakeup_cb: handleTerminalWakeup,
            action_cb: handleTerminalAction,
            read_clipboard_cb: readTerminalClipboard,
            confirm_read_clipboard_cb: nil,
            write_clipboard_cb: writeTerminalClipboard,
            close_surface_cb: closeTerminalSurface
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

    fileprivate func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    deinit {
        if let app {
            ghostty_app_free(app)
        }
    }
}
