// ABOUTME: Reads the Ghostty terminal palette and derives a MonacoTheme that matches the terminal colors.
// ABOUTME: Maps ANSI palette indices to syntax token types (keywords, strings, types, etc.).

import Cocoa

/// Reads foreground, background, and the 16-color ANSI palette from a Ghostty config
/// and maps them to a `MonacoTheme` for the source editor.
struct TerminalPalette {
    let foreground: NSColor
    let background: NSColor
    let ansi: [NSColor] // exactly 16 entries (ANSI colors 0-15)

    /// Read colors from an existing Ghostty config via `ghostty_config_get`.
    @discardableResult
    static func from(_ config: ghostty_config_t) -> TerminalPalette {
        // Read foreground
        var fg = ghostty_config_color_s()
        let fgKey = "foreground"
        ghostty_config_get(config, &fg, fgKey, UInt(fgKey.count))

        // Read background
        var bg = ghostty_config_color_s()
        let bgKey = "background"
        ghostty_config_get(config, &bg, bgKey, UInt(bgKey.count))

        // Read full 256-color palette
        var palette = ghostty_config_palette_s()
        let palKey = "palette"
        ghostty_config_get(config, &palette, palKey, UInt(palKey.count))

        // Extract the first 16 ANSI colors from the palette.
        // Swift imports C fixed-size arrays as tuples; use withUnsafePointer to iterate.
        let ansiColors: [NSColor] = withUnsafePointer(to: &palette.colors) { tuplePtr in
            tuplePtr.withMemoryRebound(to: ghostty_config_color_s.self, capacity: 16) { ptr in
                (0 ..< 16).map { i in
                    let c = ptr[i]
                    return NSColor(
                        red: CGFloat(c.r) / 255,
                        green: CGFloat(c.g) / 255,
                        blue: CGFloat(c.b) / 255,
                        alpha: 1
                    )
                }
            }
        }

        return TerminalPalette(
            foreground: NSColor(
                red: CGFloat(fg.r) / 255,
                green: CGFloat(fg.g) / 255,
                blue: CGFloat(fg.b) / 255,
                alpha: 1
            ),
            background: NSColor(
                red: CGFloat(bg.r) / 255,
                green: CGFloat(bg.g) / 255,
                blue: CGFloat(bg.b) / 255,
                alpha: 1
            ),
            ansi: ansiColors
        )
    }

    // MARK: - ANSI → MonacoTheme Mapping

    //
    // Index | ANSI Name      | Token
    // ------|----------------|------------------
    // 1     | Red            | keywords
    // 2     | Green          | strings
    // 3     | Yellow         | numbers, characters
    // 4     | Blue           | values
    // 5     | Magenta        | commands
    // 6     | Cyan           | types
    // 8     | Bright Black   | comments (italic), invisibles
    // 9     | Bright Red     | attributes
    //
    // Derived:
    //   selection    = palette[4] (blue) at 40% alpha
    //   lineHighlight = foreground at 5% alpha

    var monacoTheme: MonacoTheme {
        MonacoTheme(
            base: "vs-dark",
            rules: [
                // Keywords (ANSI Red)
                ["token": "keyword", "foreground": hexString(ansi[1])],
                ["token": "keyword.control", "foreground": hexString(ansi[1])],
                ["token": "keyword.operator", "foreground": hexString(ansi[1])],
                ["token": "tag", "foreground": hexString(ansi[1])],
                // Strings (ANSI Green)
                ["token": "string", "foreground": hexString(ansi[2])],
                ["token": "string.escape", "foreground": hexString(ansi[3])],
                ["token": "attribute.value", "foreground": hexString(ansi[2])],
                // Numbers (ANSI Yellow)
                ["token": "number", "foreground": hexString(ansi[3])],
                ["token": "number.float", "foreground": hexString(ansi[3])],
                ["token": "number.hex", "foreground": hexString(ansi[3])],
                // Values / Functions (ANSI Blue)
                ["token": "variable.predefined", "foreground": hexString(ansi[4])],
                ["token": "constant", "foreground": hexString(ansi[4])],
                ["token": "function", "foreground": hexString(ansi[4])],
                ["token": "function.declaration", "foreground": hexString(ansi[4])],
                // Commands / Annotations (ANSI Magenta)
                ["token": "annotation", "foreground": hexString(ansi[5])],
                ["token": "decorator", "foreground": hexString(ansi[5])],
                ["token": "metatag", "foreground": hexString(ansi[5])],
                // Types (ANSI Cyan)
                ["token": "type", "foreground": hexString(ansi[6])],
                ["token": "type.identifier", "foreground": hexString(ansi[6])],
                ["token": "class", "foreground": hexString(ansi[6])],
                ["token": "interface", "foreground": hexString(ansi[6])],
                ["token": "enum", "foreground": hexString(ansi[6])],
                ["token": "struct", "foreground": hexString(ansi[6])],
                // Comments (ANSI Bright Black, italic)
                ["token": "comment", "foreground": hexString(ansi[8]), "fontStyle": "italic"],
                ["token": "comment.line", "foreground": hexString(ansi[8]), "fontStyle": "italic"],
                ["token": "comment.block", "foreground": hexString(ansi[8]), "fontStyle": "italic"],
                // Attributes (ANSI Bright Red)
                ["token": "attribute.name", "foreground": hexString(ansi[9])],
                ["token": "regexp", "foreground": hexString(ansi[9])],
                // Plain text (foreground)
                ["token": "variable", "foreground": hexString(foreground)],
                ["token": "delimiter", "foreground": hexString(foreground)],
                ["token": "operator", "foreground": hexString(foreground)],
            ],
            colors: [
                "editor.background": hexColorString(background),
                "editor.foreground": hexColorString(foreground),
                "editor.lineHighlightBackground": hexColorString(foreground, alpha: 0.05),
                "editor.lineHighlightBorder": "#00000000",
                "editor.selectionBackground": hexColorString(ansi[4], alpha: 0.40),
                "editorCursor.foreground": hexColorString(foreground),
                "editorWhitespace.foreground": hexColorString(ansi[8]),
                "editorLineNumber.foreground": hexColorString(ansi[8]),
                "editorLineNumber.activeForeground": hexColorString(foreground),
                "editorIndentGuide.background1": hexColorString(ansi[8], alpha: 0.15),
                "editorWidget.background": hexColorString(background),
            ]
        )
    }

    // MARK: - Hex Conversion

    private func hexString(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "FFFFFF" }
        return String(
            format: "%02X%02X%02X",
            Int(c.redComponent * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent * 255)
        )
    }

    private func hexColorString(_ color: NSColor, alpha: CGFloat = 1.0) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        if alpha < 1.0 {
            return String(
                format: "#%02X%02X%02X%02X",
                Int(c.redComponent * 255),
                Int(c.greenComponent * 255),
                Int(c.blueComponent * 255),
                Int(alpha * 255)
            )
        }
        return String(
            format: "#%02X%02X%02X",
            Int(c.redComponent * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent * 255)
        )
    }
}
