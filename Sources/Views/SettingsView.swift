// ABOUTME: Application settings panel.
// ABOUTME: Language override and future configuration options.

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ff2.languageOverride") private var languageOverride: String = ""

    private var availableLanguages: [(code: String, name: String)] {
        var languages: [(String, String)] = [("", NSLocalizedString("System Default", comment: ""))]
        let bundles = Bundle.main.localizations.filter { $0 != "Base" }.sorted()
        let locale = Locale.current
        for code in bundles {
            let name = locale.localizedString(forLanguageCode: code) ?? code
            languages.append((code, name.capitalized))
        }
        return languages
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            Form {
                Picker("Language", selection: $languageOverride) {
                    ForEach(availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: languageOverride) { _, newValue in
                    applyLanguage(newValue)
                }
            }
            .formStyle(.grouped)

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }

    private func applyLanguage(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }
}
