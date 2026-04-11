// ABOUTME: Maps file names and extensions to SF Symbols for the file tree.
// ABOUTME: All icons use .secondary color; only the symbol shape distinguishes file types.

import SwiftUI

struct FileTypeIcon {
    let symbolName: String

    static func icon(for fileName: String) -> FileTypeIcon {
        // Check exact filename matches first
        switch fileName.lowercased() {
        case "dockerfile", "containerfile":
            return FileTypeIcon(symbolName: "shippingbox")
        case "makefile", "gnumakefile":
            return FileTypeIcon(symbolName: "terminal")
        case ".gitignore", ".gitattributes", ".gitmodules":
            return FileTypeIcon(symbolName: "arrow.triangle.branch")
        case ".env", ".env.local", ".env.development", ".env.production":
            return FileTypeIcon(symbolName: "lock")
        case "license", "licence":
            return FileTypeIcon(symbolName: "doc.text")
        default:
            break
        }

        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        // Swift
        case "swift":
            return FileTypeIcon(symbolName: "swift")

        // Code (all languages)
        case "js", "mjs", "cjs", "jsx",
             "ts", "mts", "cts", "tsx",
             "py", "pyw", "pyi",
             "rs", "go", "rb", "erb",
             "c", "h", "cpp", "cc", "cxx", "hpp", "hh", "m", "mm",
             "java", "kt", "kts", "php", "dart", "lua", "r":
            return FileTypeIcon(symbolName: "curlybraces")

        // Web
        case "html", "htm":
            return FileTypeIcon(symbolName: "globe")

        case "css", "scss", "sass", "less":
            return FileTypeIcon(symbolName: "paintbrush")

        // Config / Data
        case "json", "jsonc", "yaml", "yml", "toml",
             "xml", "plist", "xib", "storyboard",
             "ini", "cfg", "conf":
            return FileTypeIcon(symbolName: "gearshape")

        // Shell
        case "sh", "bash", "zsh", "fish":
            return FileTypeIcon(symbolName: "terminal")

        // Markdown / Docs
        case "md", "markdown", "rst", "txt":
            return FileTypeIcon(symbolName: "doc.richtext")

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "ico", "webp", "bmp", "tiff":
            return FileTypeIcon(symbolName: "photo")

        // Fonts
        case "ttf", "otf", "woff", "woff2":
            return FileTypeIcon(symbolName: "textformat")

        // SQL
        case "sql":
            return FileTypeIcon(symbolName: "cylinder")

        // GraphQL
        case "graphql", "gql":
            return FileTypeIcon(symbolName: "point.3.connected.trianglepath.dotted")

        // Diff / Patch
        case "diff", "patch":
            return FileTypeIcon(symbolName: "plus.forwardslash.minus")

        // Lock files
        case "lock":
            return FileTypeIcon(symbolName: "lock")

        // Archives
        case "zip", "tar", "gz", "bz2", "xz", "rar", "7z":
            return FileTypeIcon(symbolName: "doc.zipper")

        // Binary / Compiled
        case "wasm", "o", "dylib", "so", "a":
            return FileTypeIcon(symbolName: "cpu")

        default:
            return FileTypeIcon(symbolName: "doc")
        }
    }
}
