// ABOUTME: Update notification banner shown in the sidebar when a new version is available.
// ABOUTME: DMG users get Sparkle's native flow; Homebrew users see a popover with the brew command.

import SwiftUI

struct UpdateBanner: View {
    let version: String
    let pendingReleases: [AppcastRelease]
    @ObservedObject var updater: Updater

    @State private var isHovering = false
    @State private var showBrewPopover = false

    var body: some View {
        Button {
            if updater.isConfigured {
                updater.checkForUpdates()
            } else {
                showBrewPopover = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 11))
                Text("v\(version) available")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundStyle(isHovering ? .white : .white.opacity(0.9))
            .background(Color(nsColor: NSColor(red: 0.55, green: 0.15, blue: 0.2, alpha: 1.0)))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .onHover { isHovering = $0 }
        .popover(isPresented: $showBrewPopover, arrowEdge: .top) {
            BrewUpdatePopover(pendingReleases: pendingReleases)
        }
    }
}

private struct BrewUpdatePopover: View {
    let pendingReleases: [AppcastRelease]

    @State private var copied = false

    private static let brewCommand = "brew upgrade factory-floor"

    private var latestVersion: String {
        pendingReleases.first?.version ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("v\(latestVersion) available")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "arrow.up.circle.fill")
            }

            HStack(spacing: 0) {
                Text(Self.brewCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.brewCommand, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(copied ? .green : .secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 4)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            if !pendingReleases.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(pendingReleases.enumerated()), id: \.offset) { _, release in
                            ReleaseEntryView(release: release)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

private struct ReleaseEntryView: View {
    let release: AppcastRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("v\(release.version)")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                if let url = release.releaseNotesURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                }
            }

            if let notes = release.releaseNotes {
                ReleaseNotesText(html: notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReleaseNotesText: View {
    let html: String

    var body: some View {
        if let attributed = renderHTML(html) {
            Text(attributed)
        } else {
            Text(html)
        }
    }

    private func renderHTML(_ html: String) -> AttributedString? {
        let wrapped = "<style>body { font-family: -apple-system; font-size: 11px; }</style>\(html)"
        guard let data = wrapped.data(using: .utf8),
              let nsAttr = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil
              )
        else { return nil }
        return try? AttributedString(nsAttr, including: \.swiftUI)
    }
}
