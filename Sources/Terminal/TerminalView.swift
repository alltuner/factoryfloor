// ABOUTME: NSView subclass that hosts a single ghostty terminal surface.
// ABOUTME: Handles keyboard, mouse, resize, and focus events for the terminal.

import Cocoa
import os

private let logger = Logger(subsystem: "factoryfloor", category: "terminal-view")

extension Notification.Name {
    static let terminalChildExited = Notification.Name("factoryfloor.terminalChildExited")
    static let terminalActivity = Notification.Name("ff2.terminalActivity")
}

@MainActor
final class TerminalView: NSView {
    /// Maps ghostty surface pointers to their owning views.
    nonisolated(unsafe) static var surfaceRegistry: [UnsafeMutableRawPointer: TerminalView] = [:]

    nonisolated static func view(for surface: ghostty_surface_t) -> TerminalView? {
        surfaceRegistry[surface]
    }

    private(set) nonisolated(unsafe) var surface: ghostty_surface_t?
    nonisolated(unsafe) var workstreamID: UUID?
    /// Last logical (point) size reported to the surface. Stored so
    /// `viewDidChangeBackingProperties` can re-report the correct framebuffer
    /// size after a scale factor change.
    private var contentSize: CGSize = .zero
    private var trackingArea: NSTrackingArea?
    private var markedText = NSMutableAttributedString()
    private var keyTextAccumulator: [String]?
    private var activityDebounceWork: DispatchWorkItem?

    /// Characters that need backslash-escaping when dropping paths into a terminal.
    private static let shellEscapeCharacters = "\\ ()[]{}<>\"'`!#$&;|*?\t"

    /// Escape shell-sensitive characters so dropped paths are safe in a live terminal buffer.
    private static func shellEscape(_ str: String) -> String {
        var result = str
        for char in shellEscapeCharacters {
            result = result.replacingOccurrences(of: String(char), with: "\\\(char)")
        }
        return result
    }

    private static let dropTypes: Set<NSPasteboard.PasteboardType> = [
        .string,
        .fileURL,
        .URL,
    ]

    init(app: ghostty_app_t, workingDirectory: String? = nil, command: String? = nil, initialInput: String? = nil, environmentVars: [String: String] = [:], waitAfterCommand: Bool = true) {
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        wantsLayer = true
        layer?.isOpaque = true

        registerForDraggedTypes(Array(Self.dropTypes))

        var config = ghostty_surface_config_new()
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(
                nsview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        config.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        config.font_size = 0 // inherit from ghostty config
        config.wait_after_command = waitAfterCommand
        config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // Heap-allocate C strings for env vars so pointers remain valid until surface creation.
        var cStringPool: [UnsafeMutablePointer<CChar>] = []
        defer { cStringPool.forEach { free($0) } }
        var cEnvVars = environmentVars.map { key, value -> ghostty_env_var_s in
            let cKey = strdup(key)!
            let cValue = strdup(value)!
            cStringPool.append(cKey)
            cStringPool.append(cValue)
            return ghostty_env_var_s(key: UnsafePointer(cKey), value: UnsafePointer(cValue))
        }

        // Use nested withCString to keep all C strings alive during surface creation
        let createSurface = { (cfg: inout ghostty_surface_config_s) in
            self.surface = ghostty_surface_new(app, &cfg)
        }

        cEnvVars.withUnsafeMutableBufferPointer { envBuf in
            config.env_vars = envBuf.baseAddress
            config.env_var_count = envBuf.count

            func applyAndCreate(_ cfg: inout ghostty_surface_config_s) {
                if let workingDirectory {
                    workingDirectory.withCString { wdPtr in
                        cfg.working_directory = wdPtr
                        if let command {
                            command.withCString { cmdPtr in
                                cfg.command = cmdPtr
                                if let initialInput {
                                    initialInput.withCString { iiPtr in
                                        cfg.initial_input = iiPtr
                                        createSurface(&cfg)
                                    }
                                } else {
                                    createSurface(&cfg)
                                }
                            }
                        } else if let initialInput {
                            initialInput.withCString { iiPtr in
                                cfg.initial_input = iiPtr
                                createSurface(&cfg)
                            }
                        } else {
                            createSurface(&cfg)
                        }
                    }
                } else if let command {
                    command.withCString { cmdPtr in
                        cfg.command = cmdPtr
                        createSurface(&cfg)
                    }
                } else {
                    createSurface(&cfg)
                }
            }

            applyAndCreate(&config)
        }

        guard let surface else {
            logger.error("ghostty_surface_new failed")
            return
        }

        Self.surfaceRegistry[surface] = self
        updateTrackingAreas()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Explicitly free the ghostty surface and remove from registry.
    /// Call this before removing from the cache to ensure the process is killed immediately.
    func destroy() {
        guard let surface else { return }
        Self.surfaceRegistry.removeValue(forKey: surface)
        ghostty_surface_free(surface)
        self.surface = nil
    }

    deinit {
        if let surface {
            ghostty_surface_free(surface)
        }
    }

    // MARK: - View lifecycle

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, false)
        }
        return result
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let surface else { return }

        if let screen = window?.screen {
            ghostty_surface_set_display_id(surface, screen.displayID)
        }

        // Use backingScaleFactor directly here — the frame may still be the
        // init placeholder (800×600) before Auto Layout runs, so deriving
        // scale via convertToBacking(frame) would be unreliable.
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        ghostty_surface_set_content_scale(surface, scale, scale)

        if let window {
            layer?.contentsScale = window.backingScaleFactor
        }

        // Defer size reporting to let Auto Layout settle first.
        // Without this, surfaces added dynamically (e.g., new terminal splits)
        // report the init frame (800x600) instead of their actual layout size.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let size = self.bounds.size
            if size.width > 0, size.height > 0 {
                self.notifySizeChanged(size)
            }
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        if let window {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.contentsScale = window.backingScaleFactor
            CATransaction.commit()
        }

        guard let surface else { return }

        let fbFrame = convertToBacking(frame)
        let xScale = frame.size.width > 0 ? fbFrame.size.width / frame.size.width : 1.0
        let yScale = frame.size.height > 0 ? fbFrame.size.height / frame.size.height : 1.0
        ghostty_surface_set_content_scale(surface, xScale, yScale)

        // Scale changed so the framebuffer size changed — re-report.
        if contentSize.width > 0, contentSize.height > 0 {
            reportSizeToSurface(contentSize)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        notifySizeChanged(newSize)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    func setFocused(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
        if focused {
            window?.makeFirstResponder(self)
        }
    }

    func setVisible(_ visible: Bool) {
        guard let surface else { return }
        ghostty_surface_set_occlusion(surface, visible)
    }

    /// Notify the Ghostty surface of a size change, skipping if the size
    /// hasn't changed. Uses `convertToBacking()` for robust coordinate
    /// conversion, matching Ghostty's own `sizeDidChange()` implementation.
    func notifySizeChanged(_ size: CGSize) {
        guard size != contentSize else { return }
        contentSize = size
        reportSizeToSurface(size)
    }

    /// Push the framebuffer size to Ghostty unconditionally (no dedup).
    private func reportSizeToSurface(_ size: CGSize) {
        guard let surface else { return }
        let scaledSize = convertToBacking(size)
        let w = UInt32(scaledSize.width)
        let h = UInt32(scaledSize.height)
        guard w > 0, h > 0 else { return }
        ghostty_surface_set_size(surface, w, h)
    }

    func surfaceClosed() {
        NotificationCenter.default.post(name: .terminalSurfaceClosed, object: self)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard surface != nil else {
            interpretKeyEvents([event])
            return
        }

        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS

        // Use interpretKeyEvents to handle text composition (IME, dead keys, etc).
        // keyTextAccumulator collects text produced by insertText calls during this.
        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }

        // Track whether we were already composing before this event so we can
        // detect when a dead key / IME composition ends.
        let markedTextBefore = markedText.length > 0

        interpretKeyEvents([event])

        // Sync preedit state with libghostty so it can render the compose
        // indicator. Only clear a previous preedit if we had one before.
        syncPreedit(clearIfNeeded: markedTextBefore)

        if let textList = keyTextAccumulator, !textList.isEmpty {
            // Composition resolved — send the composed text as real input.
            for text in textList {
                _ = sendKeyEvent(action, event: event, text: text)
            }
        } else {
            // No composed text. Mark as composing if we're in a preedit state
            // or just exited one (e.g. backspace cancelling a dead key).
            let text = Self.ghosttyCharacters(for: event)
            _ = sendKeyEvent(
                action, event: event, text: text,
                composing: markedText.length > 0 || markedTextBefore
            )
        }

        reportActivity()
    }

    /// Debounced activity notification (at most once per 30 seconds).
    private func reportActivity() {
        guard let workstreamID else { return }
        guard activityDebounceWork == nil else { return }
        NotificationCenter.default.post(name: .terminalActivity, object: workstreamID)
        let work = DispatchWorkItem { [weak self] in
            self?.activityDebounceWork = nil
        }
        activityDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    override func keyUp(with event: NSEvent) {
        _ = sendKeyEvent(GHOSTTY_ACTION_RELEASE, event: event)
    }

    override func flagsChanged(with event: NSEvent) {
        let mod: UInt32
        switch event.keyCode {
        case 0x39: mod = GHOSTTY_MODS_CAPS.rawValue
        case 0x38, 0x3C: mod = GHOSTTY_MODS_SHIFT.rawValue
        case 0x3B, 0x3E: mod = GHOSTTY_MODS_CTRL.rawValue
        case 0x3A, 0x3D: mod = GHOSTTY_MODS_ALT.rawValue
        case 0x37, 0x36: mod = GHOSTTY_MODS_SUPER.rawValue
        default: return
        }

        // Don't send modifier events during IME composition.
        if hasMarkedText() { return }

        let mods = Self.eventMods(event)

        // If the modifier bit is active it might be a press — but we
        // also check the device-specific mask so that releasing one side
        // of a modifier while the other side is held is correctly
        // detected as a release.
        var action = GHOSTTY_ACTION_RELEASE
        if mods.rawValue & mod != 0 {
            let sidePressed: Bool
            switch event.keyCode {
            case 0x38:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICELSHIFTKEYMASK) != 0
            case 0x3C:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICERSHIFTKEYMASK) != 0
            case 0x3B:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICELCTLKEYMASK) != 0
            case 0x3E:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICERCTLKEYMASK) != 0
            case 0x3A:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICELALTKEYMASK) != 0
            case 0x3D:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICERALTKEYMASK) != 0
            case 0x37:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICELCMDKEYMASK) != 0
            case 0x36:
                sidePressed = event.modifierFlags.rawValue
                    & UInt(NX_DEVICERCMDKEYMASK) != 0
            default:
                sidePressed = true
            }
            if sidePressed {
                action = GHOSTTY_ACTION_PRESS
            }
        }

        _ = sendKeyEvent(action, event: event)
    }

    /// Build and send a ghostty_input_key_s from an NSEvent.
    private func sendKeyEvent(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        text: String? = nil,
        composing: Bool = false
    ) -> Bool {
        guard let surface else { return false }

        var keyEv = ghostty_input_key_s()
        keyEv.action = action
        keyEv.keycode = UInt32(event.keyCode)
        keyEv.mods = Self.eventMods(event)

        // ctrl and command don't contribute to text translation
        let consumedFlags = event.modifierFlags.subtracting([.control, .command])
        keyEv.consumed_mods = Self.flagsToGhosttyMods(consumedFlags)

        // Unshifted codepoint: the character with NO modifiers applied.
        // Must use byApplyingModifiers([]) not charactersIgnoringModifiers,
        // because the latter still changes behavior with ctrl pressed.
        keyEv.unshifted_codepoint = 0
        if event.type == .keyDown || event.type == .keyUp {
            if let chars = event.characters(byApplyingModifiers: []),
               let codepoint = chars.unicodeScalars.first
            {
                keyEv.unshifted_codepoint = codepoint.value
            }
        }

        keyEv.text = nil
        keyEv.composing = composing

        // For text, only pass it if it's not a control character (>= 0x20).
        // Ghostty's KeyEncoder handles ctrl character mapping internally.
        if let text, !text.isEmpty,
           let firstByte = text.utf8.first, firstByte >= 0x20
        {
            return text.withCString { ptr in
                keyEv.text = ptr
                return ghostty_surface_key(surface, keyEv)
            }
        } else {
            return ghostty_surface_key(surface, keyEv)
        }
    }

    /// Returns text suitable for ghostty key events.
    /// For control characters, strips the ctrl modifier so ghostty can handle encoding.
    private static func ghosttyCharacters(for event: NSEvent) -> String? {
        guard let characters = event.characters else { return nil }

        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            // Control character: return the char without ctrl applied
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
            // Private Use Area: function keys, no text
            if scalar.value >= 0xF700, scalar.value <= 0xF8FF {
                return nil
            }
        }

        return characters
    }

    func insertText(_ string: Any, replacementRange _: NSRange) {
        guard NSApp.currentEvent != nil else { return }

        let chars: String
        switch string {
        case let v as NSAttributedString: chars = v.string
        case let v as String: chars = v
        default: return
        }

        // If insertText is called, our preedit must be over.
        unmarkText()

        if var acc = keyTextAccumulator {
            acc.append(chars)
            keyTextAccumulator = acc
            return
        }

        // Direct text input outside of keyDown
        guard let surface else { return }
        chars.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(chars.utf8.count))
        }
    }

    func setMarkedText(_ string: Any, selectedRange _: NSRange, replacementRange _: NSRange) {
        switch string {
        case let v as NSAttributedString: markedText = NSMutableAttributedString(attributedString: v)
        case let v as String: markedText = NSMutableAttributedString(string: v)
        default: return
        }
        // If we're not inside a keyDown, sync immediately. This handles external
        // preedit updates, e.g. changing keyboard layout while composing.
        if keyTextAccumulator == nil {
            syncPreedit()
        }
    }

    func unmarkText() {
        guard markedText.length > 0 else { return }
        markedText.mutableString.setString("")
        // Notify libghostty the preedit ended (e.g. app-switch triggering
        // commitComposition, or a programmatic unmark from an input method).
        syncPreedit()
    }

    func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    func markedRange() -> NSRange {
        guard markedText.length > 0 else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: 0, length: markedText.length)
    }

    func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    func attributedSubstring(forProposedRange _: NSRange, actualRange _: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange _: NSRange, actualRange _: NSRangePointer?) -> NSRect {
        guard let surface else { return .zero }
        var x: Double = 0, y: Double = 0, w: Double = 0, h: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &w, &h)
        let point = window?.convertPoint(toScreen: convert(NSPoint(x: x, y: y), to: nil)) ?? .zero
        return NSRect(x: point.x, y: point.y, width: w, height: h)
    }

    func characterIndex(for _: NSPoint) -> Int {
        0
    }

    override func doCommand(by _: Selector) {
        // Let the input system handle commands we don't care about
    }

    /// Sync the preedit (dead key / IME compose) state with libghostty.
    private func syncPreedit(clearIfNeeded: Bool = true) {
        guard let surface else { return }
        if markedText.length > 0 {
            let str = markedText.string
            let len = str.utf8CString.count
            if len > 0 {
                str.withCString { ptr in
                    ghostty_surface_preedit(surface, ptr, UInt(len - 1))
                }
            }
        } else if clearIfNeeded {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }

    // MARK: - Drag and drop

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types else { return [] }
        guard types.contains(where: { Self.dropTypes.contains($0) }) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        let content: String?
        if let url = pb.string(forType: .URL) {
            content = Self.shellEscape(url)
        } else if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            content = urls
                .map { Self.shellEscape($0.path) }
                .joined(separator: " ")
        } else if let str = pb.string(forType: .string) {
            content = str
        } else {
            content = nil
        }

        guard let content, let surface else { return false }
        content.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(content.utf8.count))
        }
        return true
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        // Claim first responder so this surface gets keyboard input
        window?.makeFirstResponder(self)
        guard let surface else { return }
        let mods = Self.eventMods(event)
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.eventMods(event)
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.eventMods(event)
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, mods)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.eventMods(event)
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, mods)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let point = Self.ghosttyMousePoint(from: event.locationInWindow, in: self)
        let mods = Self.eventMods(event)
        ghostty_surface_mouse_pos(surface, point.x, point.y, mods)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface else { return }
        let point = Self.ghosttyMousePoint(from: event.locationInWindow, in: self)
        let mods = Self.eventMods(event)
        ghostty_surface_mouse_pos(surface, point.x, point.y, mods)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        var x = event.scrollingDeltaX
        var y = event.scrollingDeltaY
        let precision = event.hasPreciseScrollingDeltas

        if precision {
            x *= 2
            y *= 2
        }

        // Pack scroll mods matching ghostty's expectations:
        // bit 0 = precision, bits 1-3 = momentum phase
        var scrollMods: Int32 = 0
        if precision {
            scrollMods |= (1 << 0)
        }
        scrollMods |= Int32(Self.momentumValue(event.momentumPhase)) << 1
        ghostty_surface_mouse_scroll(surface, x, y, scrollMods)
    }

    private static func momentumValue(_ phase: NSEvent.Phase) -> UInt8 {
        switch phase {
        case .began: 1
        case .stationary: 2
        case .changed: 3
        case .ended: 4
        case .cancelled: 5
        case .mayBegin: 6
        default: 0
        }
    }

    // MARK: - Modifier translation

    private static func eventMods(_ event: NSEvent) -> ghostty_input_mods_e {
        flagsToGhosttyMods(event.modifierFlags)
    }

    static func ghosttyMousePoint(from windowPoint: NSPoint, in view: NSView) -> NSPoint {
        let point = view.convert(windowPoint, from: nil)
        return NSPoint(x: point.x, y: view.frame.height - point.y)
    }

    private static func flagsToGhosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(rawValue: mods)
    }
}

extension TerminalView: @preconcurrency NSTextInputClient {}

// MARK: - NSScreen display ID helper

extension NSScreen {
    var displayID: UInt32 {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return screenNumber.uint32Value
    }
}
