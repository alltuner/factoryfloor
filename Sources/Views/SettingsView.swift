// ABOUTME: Application settings pane displayed in the detail area.
// ABOUTME: Session, tools, default apps, and language settings.

import SwiftUI

struct SettingsView: View {
    @AppStorage("ff2.languageOverride") private var languageOverride: String = ""
    @AppStorage("ff2.tmuxMode") private var tmuxMode: Bool = false
    @AppStorage("ff2.defaultTerminal") private var defaultTerminal: String = ""
    @AppStorage("ff2.defaultBrowser") private var defaultBrowser: String = ""

    @EnvironmentObject private var appEnv: AppEnvironment

    var body: some View {
        Form {
            // MARK: - Environment
            Section {
                ToolRow(
                    name: "claude",
                    status: appEnv.toolStatus.claude,
                    version: appEnv.toolStatus.claudeVersion
                )
                ToolRow(
                    name: "gh",
                    status: appEnv.toolStatus.gh,
                    version: appEnv.toolStatus.ghVersion,
                    detail: appEnv.toolStatus.ghAuthDetail
                )
                ToolRow(
                    name: "git",
                    status: appEnv.toolStatus.git,
                    version: appEnv.toolStatus.gitVersion
                )
                ToolRow(
                    name: "tmux",
                    status: appEnv.toolStatus.tmux,
                    version: appEnv.toolStatus.tmuxVersion
                )
            } header: {
                HStack {
                    Text("Environment")
                    Spacer()
                    Button(action: { appEnv.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .rotationEffect(.degrees(appEnv.isDetecting ? 360 : 0))
                            .animation(appEnv.isDetecting ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: appEnv.isDetecting)
                    }
                    .buttonStyle(.plain)
                    .disabled(appEnv.isDetecting)
                }
            }

            // MARK: - Terminal
            Section("Terminal") {
                Toggle("Tmux Mode", isOn: $tmuxMode)
                    .disabled(!appEnv.toolStatus.tmux.isInstalled)
                Text("Makes sessions persist across app restarts. Sessions are lost on system restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !appEnv.toolStatus.tmux.isInstalled {
                    Text("Requires tmux to be installed.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Picker("External Terminal", selection: $defaultTerminal) {
                    Text("None").tag("")
                    ForEach(appEnv.installedTerminals) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
            }

            // MARK: - Applications
            Section("Applications") {
                Picker("Default Browser", selection: $defaultBrowser) {
                    Text("System Default").tag("")
                    ForEach(appEnv.installedBrowsers) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
            }

            // MARK: - Language
            Section("Language") {
                Picker("Language", selection: $languageOverride) {
                    ForEach(availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: languageOverride) { _, newValue in
                    applyLanguage(newValue)
                }

                if !languageOverride.isEmpty {
                    Text("Restart the app for the language change to take effect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var availableLanguages: [(code: String, name: String)] {
        var languages: [(String, String)] = [("", NSLocalizedString("System Default", comment: ""))]
        let bundles = Bundle.main.localizations.filter { $0 != "Base" }.sorted()
        for code in bundles {
            let nativeLocale = Locale(identifier: code)
            let name = nativeLocale.localizedString(forLanguageCode: code) ?? code
            languages.append((code, name.capitalized))
        }
        return languages
    }

    private func applyLanguage(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }
}

// MARK: - Tool Detection

enum BinaryStatus {
    case notFound
    case found(String)

    var isInstalled: Bool {
        if case .found = self { return true }
        return false
    }

    var path: String? {
        if case .found(let p) = self { return p }
        return nil
    }
}

struct ToolStatus {
    var tmux: BinaryStatus = .notFound
    var tmuxVersion: String?
    var claude: BinaryStatus = .notFound
    var claudeVersion: String?
    var gh: BinaryStatus = .notFound
    var ghVersion: String?
    var ghAuthDetail: String?
    var git: BinaryStatus = .notFound
    var gitVersion: String?

    static func detect() async -> ToolStatus {
        var status = ToolStatus()

        status.tmux = findBinary("tmux")
        if let path = status.tmux.path {
            status.tmuxVersion = runForVersion(path, args: ["-V"])
        }

        status.claude = findBinary("claude")
        if let path = status.claude.path {
            status.claudeVersion = runForVersion(path, args: ["--version"])
        }

        status.gh = findBinary("gh")
        if let path = status.gh.path {
            status.ghVersion = runForVersion(path, args: ["--version"])
            status.ghAuthDetail = checkGhAuth(path)
        }

        status.git = findBinary("git")
        if let path = status.git.path {
            status.gitVersion = runForVersion(path, args: ["--version"])
        }

        return status
    }

    private static func findBinary(_ name: String) -> BinaryStatus {
        let searchPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
        ]

        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return .found(path)
            }
        }

        // Fallback to which
        if let output = runCommand("/usr/bin/which", args: [name]),
           !output.isEmpty {
            return .found(output)
        }

        return .notFound
    }

    private static func runForVersion(_ path: String, args: [String]) -> String? {
        guard let output = runCommand(path, args: args) else { return nil }
        // Extract just the version number from output like "tmux 3.4" or "gh version 2.40.1"
        let trimmed = output
            .replacingOccurrences(of: "tmux ", with: "")
            .replacingOccurrences(of: "gh version ", with: "")
        // Take first line only
        return trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces)
    }

    private static func checkGhAuth(_ ghPath: String) -> String? {
        guard let output = runCommand(ghPath, args: ["auth", "status"], includeStderr: true) else {
            return "Not authenticated"
        }
        // Parse "Logged in to github.com account username"
        if let range = output.range(of: "account ") {
            let afterAccount = output[range.upperBound...]
            let username = afterAccount.prefix(while: { !$0.isWhitespace && $0 != "(" })
            if !username.isEmpty {
                return String(username)
            }
        }
        if output.contains("Logged in") {
            return "Authenticated"
        }
        return "Not authenticated"
    }

    private static func runCommand(_ path: String, args: [String], includeStderr: Bool = false) -> String? {
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = includeStderr ? pipe : errPipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 || includeStderr else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

private struct ToolRow: View {
    let name: String
    let status: BinaryStatus
    var version: String?
    var detail: String?

    var body: some View {
        HStack {
            Image(systemName: status.isInstalled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(status.isInstalled ? .green : .secondary)

            Text(name)
                .font(.system(.body, design: .monospaced))

            if let version {
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status.isInstalled {
                if let detail {
                    let isAuth = detail != "Not authenticated"
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAuth ? .green : .orange)
                            .frame(width: 6, height: 6)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - App Detection

struct AppInfo: Identifiable {
    let name: String
    let bundleID: String
    var id: String { bundleID }

    private static func isAppInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func detectTerminals() -> [AppInfo] {
        let candidates: [(String, String)] = [
            ("Ghostty", "com.mitchellh.ghostty"),
            ("iTerm2", "com.googlecode.iterm2"),
            ("Terminal", "com.apple.Terminal"),
            ("Warp", "dev.warp.Warp-Stable"),
            ("Alacritty", "org.alacritty"),
            ("kitty", "net.kovidgoyal.kitty"),
        ]
        return candidates.compactMap { (name, id) in
            isAppInstalled(id) ? AppInfo(name: name, bundleID: id) : nil
        }
    }

    static func detectBrowsers() -> [AppInfo] {
        let candidates: [(String, String)] = [
            ("Safari", "com.apple.Safari"),
            ("Google Chrome", "com.google.Chrome"),
            ("Firefox", "org.mozilla.firefox"),
            ("Arc", "company.thebrowser.Browser"),
            ("Brave", "com.brave.Browser"),
            ("Microsoft Edge", "com.microsoft.edgemac"),
            ("Opera", "com.operasoftware.Opera"),
        ]
        return candidates.compactMap { (name, id) in
            isAppInstalled(id) ? AppInfo(name: name, bundleID: id) : nil
        }
    }
}
