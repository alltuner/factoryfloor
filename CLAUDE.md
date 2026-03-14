# ff2 Project Instructions

## Localization

All user-facing strings MUST use localization. Never hardcode strings directly in SwiftUI views or code.

### Rules
- **SwiftUI Text/Button/Label**: Use string literals directly (e.g., `Text("Cancel")`). SwiftUI automatically treats these as `LocalizedStringKey` and looks them up in `Localizable.strings`.
- **AppKit APIs** (NSOpenPanel, NSAlert, etc.): Use `NSLocalizedString("string", comment: "")`.
- **String interpolation in Text**: Works automatically. `Text("Remove \(name)")` generates the right localization key.
- **Enum raw values used in UI** (like `ProjectSortOrder`): These need manual localization if displayed.
- **Every new user-facing string** must be added to `Resources/en.lproj/Localizable.strings`.

### Adding a new string
1. Use the string in code as described above
2. Add the English key-value pair to `Resources/en.lproj/Localizable.strings`
3. Add translations to any other `xx.lproj/Localizable.strings` files that exist

### Adding a new language
1. Copy `Resources/en.lproj` to `Resources/xx.lproj` (e.g., `es.lproj` for Spanish)
2. Translate all values in `Localizable.strings` (keep the keys unchanged)
3. Run `xcodegen generate` to pick up the new lproj directory
4. The app will auto-select the language based on macOS system preferences, or the user can override it in Settings

### Extracting strings
To find hardcoded strings that should be localized:
```bash
grep -rn 'Text("' Sources/ | grep -v '//'
grep -rn 'Button("' Sources/ | grep -v '//'
grep -rn 'Label("' Sources/ | grep -v '//'
```

## Build & Run
- `./dev.sh build` - Debug build
- `./dev.sh build-release` - Release build (optimized)
- `./dev.sh test` - Run tests
- `./dev.sh br` - Build and run (debug)
- `./dev.sh br-release` - Build and run (release)
- `./dev.sh run [dir]` - Run (uses URL scheme, works with running instance)
- `./dev.sh clean` - Clean build artifacts

## Architecture
- SwiftUI sidebar + AppKit terminal views (Metal GPU-rendered via libghostty)
- XcodeGen for project generation (`project.yml` -> xcodeproj, do not edit xcodeproj directly)
- Ghostty as git submodule, xcframework built with `zig build`
- Bridging header approach for GhosttyKit (not module import)
- Single-window app via `Window` (not `WindowGroup`)
- `ff2://` URL scheme for single-instance behavior
