// ABOUTME: Update notification banner shown in the sidebar when a new version is available.
// ABOUTME: DMG users get Sparkle's native flow; Homebrew users see a popover with the brew command.

import SwiftUI

struct UpdateBanner: View {
    let version: String
    let releaseNotesURL: URL?
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
            BrewUpdatePopover(version: version, releaseNotesURL: releaseNotesURL)
        }
    }
}

private struct BrewUpdatePopover: View {
    let version: String
    let releaseNotesURL: URL?

    @State private var copied = false

    private static let brewCommand = "brew upgrade factory-floor"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("v\(version) available")
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

            if let url = releaseNotesURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("Release Notes")
                            .font(.system(size: 11))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
