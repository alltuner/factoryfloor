# Contributing to Factory Floor

Thank you for your interest in contributing to Factory Floor! This document covers the basics of how to get started.

## Getting started

### Prerequisites

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Ghostty submodule initialized (`git submodule update --init`)

### Building

```bash
xcodegen generate              # Generate the Xcode project from project.yml
./scripts/dev.sh build         # Debug build
./scripts/dev.sh br            # Build and run
./scripts/dev.sh test           # Run tests
```

Do **not** edit `FactoryFloor.xcodeproj` directly. It is generated from `project.yml`.

### Project structure

- `Sources/Models/` - Data models, git operations, tmux, app constants
- `Sources/Terminal/` - Ghostty integration (TerminalApp singleton, TerminalView)
- `Sources/Views/` - SwiftUI views (sidebar, settings, workspace, browser)
- `Localization/` - Localized strings (en, ca, es, sv)
- `Resources/` - Entitlements, assets, bridging header
- `website/` - Hugo + Tailwind CSS site for factory-floor.com

## How to contribute

### Bug reports

Open an [issue](https://github.com/alltuner/factoryfloor/issues) with:
- Steps to reproduce
- Expected vs actual behavior
- macOS version and app version

### Feature requests

Open an issue describing the use case, not just the solution. Context about *why* helps us evaluate and prioritize.

### Pull requests

1. Fork the repository and create a feature branch (`feat/description`, `fix/description`)
2. Follow the existing code style and conventions (see `CLAUDE.md` for details)
3. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
4. Add localized strings in all 4 languages (en, ca, es, sv) for any new user-facing text
5. Make sure `./scripts/dev.sh build` and `./scripts/dev.sh test` pass
6. Open a PR against `main`

### Translations

Factory Floor is localized in English, Catalan, Spanish, and Swedish. You can contribute translations for both the app and the website.

See [docs/TRANSLATING.md](docs/TRANSLATING.md) for the full guide, including how to improve existing translations, add new languages, and avoid common pitfalls.

### Website

The website uses Hugo with Tailwind CSS. To build locally:

```bash
cd website
hugo server
```

## Code conventions

- Use `AppConstants.appID` and `AppConstants.appName`, not hardcoded strings
- Use "directory" not "folder" in all user-facing text
- Use "Coding Agent" for the Claude terminal tab
- Use "workstream" for sub-units of a project
- All code files start with a 2-line `// ABOUTME:` comment explaining what the file does

See `CLAUDE.md` for the full set of project conventions.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
