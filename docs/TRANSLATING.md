# Translating Factory Floor

Factory Floor is localized in four languages: English (en), Catalan (ca), Spanish (es), and Swedish (sv). Contributions to improve existing translations or add new languages are welcome.

There are two independent translation surfaces: the **app** (native macOS UI) and the **website** (factory-floor.com). You can contribute to either or both.

## Translation philosophy

We treat translations as **native copywriting**, not literal word-for-word conversion. Each language should read as if it were written by a native speaker, not run through a machine translator. Adapt idioms, restructure sentences, and adjust tone to feel natural in the target language.

## App translations

The app uses Apple's standard `.strings` format. Each language has its own directory under `Localization/`.

### File structure

```
Localization/
├── en.lproj/
│   ├── Localizable.strings    # All UI strings
│   └── InfoPlist.strings      # System permission descriptions
├── ca.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
├── es.lproj/
│   └── ...
└── sv.lproj/
    └── ...
```

### String format

Strings use Apple's key-value format:

```
/* Section comment */
"Key text" = "Translated text";
```

The key (left side) is always the English string. The value (right side) is the translation. For English, key and value are identical.

### Improving existing translations

1. Open `Localization/<lang>.lproj/Localizable.strings`
2. Find the string you want to improve
3. Change the value (right side) only. Never change the key (left side).
4. Do the same in `InfoPlist.strings` if relevant

### Adding a string

When adding a new user-facing string to the app, it **must** be added to all four language files. If you don't speak one of the languages, add the English string as a placeholder and note it in your PR so someone else can translate it.

## Website translations

The website uses [Hugo](https://gohugo.io/) with two translation mechanisms: **i18n files** for UI strings used in templates, and **content files** for full pages.

### File structure

```
website/
├── hugo.toml                  # Language definitions
├── i18n/
│   ├── en.toml                # Template UI strings (English)
│   ├── ca.toml
│   ├── es.toml
│   └── sv.toml
└── content/
    ├── _index.md              # Homepage (English)
    ├── docs.md                # Docs (English)
    ├── get.md
    ├── sponsor.md
    ├── legal/privacy.md
    ├── ca/                    # Catalan content
    │   ├── _index.md
    │   ├── docs.md
    │   ├── get.md
    │   ├── sponsor.md
    │   └── legal/privacy.md
    ├── es/                    # Spanish content
    │   └── ...
    └── sv/                    # Swedish content
        └── ...
```

### i18n strings (template UI)

These are short strings used in Hugo templates (navigation, buttons, section headings). Each language has a TOML file in `website/i18n/`:

```toml
[nav_features]
other = "Features"

[hero_download]
other = "Download"
```

### Content pages

Full-page content lives in `website/content/`. English pages are at the root, and translations go in language-specific subdirectories (`ca/`, `es/`, `sv/`). Each translated page must have the same filename as its English counterpart.

### Testing website translations locally

```bash
cd website
hugo server
```

Then visit `http://localhost:1313/` for English, `http://localhost:1313/ca/` for Catalan, etc.

## Adding a new language

Adding a new language touches several files across the app and website. Here's the full checklist:

### App

1. Create `Localization/<lang>.lproj/` directory
2. Copy `Localizable.strings` and `InfoPlist.strings` from `en.lproj/`
3. Translate all values
4. Add both files to `project.yml` under the `sources` list:
   ```yaml
   - path: Localization/<lang>.lproj/Localizable.strings
     buildPhase: resources
   - path: Localization/<lang>.lproj/InfoPlist.strings
     buildPhase: resources
   ```
5. Run `xcodegen generate` to regenerate the Xcode project

### Website

1. Add a language section to `website/hugo.toml`:
   ```toml
   [languages.<lang>]
     languageCode = "<lang>"
     languageName = "Language Name"
     weight = 5
     contentDir = "content/<lang>"
   ```
2. Create `website/i18n/<lang>.toml` by copying `en.toml` and translating all values
3. Create `website/content/<lang>/` and translate each content page
4. Update the hardcoded language list in these Hugo templates (see gotcha below):
   - `website/layouts/_default/docs.html`
   - `website/layouts/partials/footer.html`

## Known gotchas

### Hugo: do not use `.AllTranslations`

Hugo's `.AllTranslations` function returns duplicates because our localized `contentDir` directories are nested inside the English `content/` directory. Instead, the language switcher uses a hardcoded list:

```go
{{ $codes := slice "en" "ca" "es" "sv" }}
```

If you add a new language, you must update this list in `docs.html` and `footer.html`. Grep for `codes := slice` to find all occurrences.

### App strings use the English text as the key

In `Localizable.strings`, the key is the English string itself. This means if you change the English text, you need to update the key in **all four** language files.

### SwiftUI vs AppKit localization

- **SwiftUI** (`Text`, `Button`, `Label`): use string literals directly. SwiftUI treats them as `LocalizedStringKey` automatically.
- **AppKit** (`NSOpenPanel`, `NSAlert`, etc.): use `NSLocalizedString("string", comment: "")`.
- **String interpolation with images**: split into `Text` concatenation, e.g. `Text("Press ") + Text(Image(systemName: "command")) + Text(" N")`.

## Questions?

Open an [issue](https://github.com/alltuner/factoryfloor/issues) or ask in your PR if anything is unclear.
