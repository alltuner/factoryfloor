// ABOUTME: Theme data structure for Monaco editor, serializable to JSON.
// ABOUTME: Maps Ghostty terminal ANSI palette to Monaco token colors.

import Cocoa

struct MonacoTheme {
    let base: String // "vs-dark" or "vs"
    let rules: [[String: String]] // token color rules
    let colors: [String: String] // editor chrome colors

    func toJSON() -> String {
        let dict: [String: Any] = [
            "base": base,
            "inherit": true,
            "rules": rules,
            "colors": colors,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // Fallback theme matching the current EditorView.fallbackTheme colors.
    // Used when Ghostty config is unavailable.
    static let fallback = MonacoTheme(
        base: "vs-dark",
        rules: [
            ["token": "keyword", "foreground": "FD5E76"],
            ["token": "keyword.control", "foreground": "FD5E76"],
            ["token": "keyword.operator", "foreground": "FD5E76"],
            ["token": "string", "foreground": "A3D468"],
            ["token": "string.escape", "foreground": "EDA35B"],
            ["token": "number", "foreground": "D9BA6B"],
            ["token": "number.float", "foreground": "D9BA6B"],
            ["token": "number.hex", "foreground": "D9BA6B"],
            ["token": "type", "foreground": "64B8A4"],
            ["token": "type.identifier", "foreground": "64B8A4"],
            ["token": "class", "foreground": "64B8A4"],
            ["token": "interface", "foreground": "64B8A4"],
            ["token": "enum", "foreground": "64B8A4"],
            ["token": "struct", "foreground": "64B8A4"],
            ["token": "comment", "foreground": "737373", "fontStyle": "italic"],
            ["token": "comment.line", "foreground": "737373", "fontStyle": "italic"],
            ["token": "comment.block", "foreground": "737373", "fontStyle": "italic"],
            ["token": "variable", "foreground": "D4D5D9"],
            ["token": "variable.predefined", "foreground": "6BA3DE"],
            ["token": "constant", "foreground": "6BA3DE"],
            ["token": "attribute.name", "foreground": "EDA35B"],
            ["token": "attribute.value", "foreground": "A3D468"],
            ["token": "tag", "foreground": "FD5E76"],
            ["token": "metatag", "foreground": "AB71C4"],
            ["token": "function", "foreground": "6BA3DE"],
            ["token": "function.declaration", "foreground": "6BA3DE"],
            ["token": "annotation", "foreground": "AB71C4"],
            ["token": "decorator", "foreground": "AB71C4"],
            ["token": "regexp", "foreground": "EDA35B"],
            ["token": "delimiter", "foreground": "D4D5D9"],
            ["token": "operator", "foreground": "D4D5D9"],
        ],
        colors: [
            "editor.background": "#1C1E24",
            "editor.foreground": "#D4D5D9",
            "editor.lineHighlightBackground": "#D4D5D90D",
            "editor.lineHighlightBorder": "#00000000",
            "editor.selectionBackground": "#3D578E66",
            "editorCursor.foreground": "#FFFFFF",
            "editorWhitespace.foreground": "#666666",
            "editorLineNumber.foreground": "#737373",
            "editorLineNumber.activeForeground": "#D4D5D9",
            "editorIndentGuide.background1": "#73737326",
            "editorWidget.background": "#1C1E24",
        ]
    )
}
