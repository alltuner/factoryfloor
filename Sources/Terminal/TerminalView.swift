// ABOUTME: NSView subclass that hosts a single ghostty terminal surface.
// ABOUTME: Handles keyboard, mouse, resize, and focus events for the terminal.

import Cocoa
import os

private let logger = Logger(subsystem: "factoryfloor", category: "terminal-view")

extension Notification.Name {
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
    private var trackingArea: NSTrackingArea?
    private var markedText = NSMutableAttributedString()
    private var keyTextAccumulator: [String]?
    private var activityDebounceWork: DispatchWorkItem?

    init(app: ghostty_app_t, workingDirectory: String? = nil, command: String? = nil, initialInput: String? = nil, environmentVars: [String: String] = [:]) {
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        wantsLayer = true
        layer?.isOpaque = true

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

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        ghostty_surface_set_content_scale(surface, scale, scale)

        // Defer size reporting to let Auto Layout settle first.
        // Without this, surfaces added dynamically (e.g., new terminal splits)
        // report the init frame (800x600) instead of their actual layout size.
        DispatchQueue.main.async { [weak self] in
            guard let self, let surface = self.surface else { return }
            let currentScale = self.window?.backingScaleFactor ?? 2.0
            let size = self.bounds.size
            let w = UInt32(size.width * currentScale)
            let h = UInt32(size.height * currentScale)
            if w > 0, h > 0 {
                ghostty_surface_set_size(surface, w, h)
            }
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let surface else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let w = UInt32(newSize.width * scale)
        let h = UInt32(newSize.height * scale)
        guard w > 0, h > 0 else { return }
        ghostty_surface_set_size(surface, w, h)
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

        interpretKeyEvents([event])

        if let textList = keyTextAccumulator, !textList.isEmpty {
            for text in textList {
                _ = sendKeyEvent(action, event: event, text: text)
            }
        } else {
            let text = Self.ghosttyCharacters(for: event)
            _ = sendKeyEvent(action, event: event, text: text)
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
        _ = sendKeyEvent(GHOSTTY_ACTION_PRESS, event: event)
    }

    /// Build and send a ghostty_input_key_s from an NSEvent.
    private func sendKeyEvent(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        text: String? = nil
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
        keyEv.composing = false

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
    }

    func unmarkText() {
        markedText.mutableString.setString("")
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
