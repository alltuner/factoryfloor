// ABOUTME: GitHub-style changes view showing stacked inline diffs for all branch changes.
// ABOUTME: Uses Monaco diff editors in a single scrollable WKWebView via MonacoDiffBridge.

import SwiftUI

enum ChangesMode: String, CaseIterable {
    case branch
    case uncommitted

    var label: String {
        switch self {
        case .branch: return NSLocalizedString("Branch", comment: "")
        case .uncommitted: return NSLocalizedString("Uncommitted", comment: "")
        }
    }
}

struct ChangesView: View {
    let workingDirectory: String
    let projectDirectory: String
    let bridge: MonacoDiffBridge

    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var fileCount = 0
    @State private var mode: ChangesMode = .branch

    var body: some View {
        VStack(spacing: 0) {
            changesToolbar
            ZStack {
                MonacoDiffView(bridge: bridge)
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if bridge.hasContent && bridge.lastMode == mode.rawValue {
                // Cached content exists for this mode — show it, refresh in background
                isLoading = false
                fileCount = bridge.lastFileCount
                backgroundRefreshIfNeeded()
            } else {
                fullLoad()
            }
        }
        .onChange(of: mode) {
            // Mode changed — always do a full load
            bridge.lastFingerprint = nil
            fullLoad()
        }
    }

    // MARK: - Toolbar

    private var changesToolbar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $mode) {
                ForEach(ChangesMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 170)
            .opacity(0.85)

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing…")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else if fileCount == 0 {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("No changes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text(String(
                    format: NSLocalizedString("%d file(s) changed", comment: ""),
                    fileCount
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Full load (first visit or explicit refresh)

    private func fullLoad() {
        isLoading = true
        let workDir = workingDirectory
        let projDir = projectDirectory
        let currentMode = mode

        DispatchQueue.global(qos: .userInitiated).async {
            let fingerprint = GitOperations.diffFingerprint(
                worktreePath: workDir,
                projectPath: projDir,
                mode: currentMode.rawValue
            )
            let (filesPayload, reviewMeta) = Self.buildPayload(
                workDir: workDir,
                projDir: projDir,
                mode: currentMode
            )

            DispatchQueue.main.async {
                fileCount = filesPayload.count
                bridge.lastFileCount = filesPayload.count
                bridge.lastFingerprint = fingerprint
                bridge.lastMode = currentMode.rawValue
                bridge.onContentReady = {
                    isLoading = false
                }
                bridge.setFiles(filesPayload, reviewGuide: reviewMeta)
            }
        }
    }

    // MARK: - Background refresh (subsequent visits)

    private func backgroundRefreshIfNeeded() {
        let workDir = workingDirectory
        let projDir = projectDirectory
        let currentMode = mode
        let cachedFingerprint = bridge.lastFingerprint

        DispatchQueue.global(qos: .userInitiated).async {
            let fingerprint = GitOperations.diffFingerprint(
                worktreePath: workDir,
                projectPath: projDir,
                mode: currentMode.rawValue
            )

            // Nothing changed — cached content is still valid
            if fingerprint == cachedFingerprint {
                return
            }

            let (filesPayload, reviewMeta) = Self.buildPayload(
                workDir: workDir,
                projDir: projDir,
                mode: currentMode
            )

            DispatchQueue.main.async {
                fileCount = filesPayload.count
                bridge.lastFileCount = filesPayload.count
                bridge.lastFingerprint = fingerprint
                bridge.lastMode = currentMode.rawValue
                isRefreshing = true
                bridge.onContentReady = {
                    isRefreshing = false
                }
                bridge.setFiles(filesPayload, reviewGuide: reviewMeta)
            }
        }
    }

    // MARK: - Payload builder

    private nonisolated static func buildPayload(
        workDir: String,
        projDir: String,
        mode: ChangesMode
    ) -> ([[String: Any]], [String: String]?) {
        let diffFiles: [GitOperations.DiffFile]
        let baseRef: String

        switch mode {
        case .branch:
            diffFiles = GitOperations.branchDiffFiles(
                worktreePath: workDir,
                projectPath: projDir
            )
            baseRef = GitOperations.mergeBase(
                worktreePath: workDir,
                projectPath: projDir
            ) ?? "HEAD"
        case .uncommitted:
            diffFiles = GitOperations.uncommittedDiffFiles(at: workDir)
            baseRef = "HEAD"
        }

        // Parse review guide (nil on missing/malformed file — graceful fallback)
        let guide = ReviewGuide.load(worktreePath: workDir)

        // Build lookups from review guide
        let orderLookup: [String: (index: Int, reason: String)]
        if let order = guide?.order {
            var lookup: [String: (index: Int, reason: String)] = [:]
            for (i, entry) in order.enumerated() {
                lookup[entry.file] = (index: i, reason: entry.reason)
            }
            orderLookup = lookup
        } else {
            orderLookup = [:]
        }

        let annotationLookup: [String: [[String: Any]]]
        if let annotations = guide?.annotations {
            var lookup: [String: [[String: Any]]] = [:]
            for ann in annotations {
                var dict: [String: Any] = ["body": ann.body]
                if let line = ann.line { dict["line"] = line }
                if let lines = ann.lines { dict["lines"] = lines }
                lookup[ann.file, default: []].append(dict)
            }
            annotationLookup = lookup
        } else {
            annotationLookup = [:]
        }

        // Reorder: files in review order first, then remaining alphabetically
        let sorted: [GitOperations.DiffFile]
        if orderLookup.isEmpty {
            sorted = diffFiles
        } else {
            let ordered = diffFiles.filter { orderLookup[$0.relativePath] != nil }
                .sorted { (orderLookup[$0.relativePath]?.index ?? 0) < (orderLookup[$1.relativePath]?.index ?? 0) }
            let rest = diffFiles.filter { orderLookup[$0.relativePath] == nil }
            sorted = ordered + rest
        }

        var filesPayload: [[String: Any]] = []
        for file in sorted {
            var entry: [String: Any] = [
                "filePath": file.relativePath,
                "status": file.status.rawValue,
                "languageId": MonacoLanguage.id(for: (file.relativePath as NSString).lastPathComponent),
            ]

            if file.status != .added {
                entry["originalText"] = GitOperations.fileContent(
                    at: workDir,
                    ref: baseRef,
                    filePath: file.relativePath
                ) ?? ""
            } else {
                entry["originalText"] = ""
            }

            if file.status != .deleted {
                let fullPath = (workDir as NSString).appendingPathComponent(file.relativePath)
                entry["modifiedText"] = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
            } else {
                entry["modifiedText"] = ""
            }

            if let reason = orderLookup[file.relativePath]?.reason {
                entry["reason"] = reason
            }
            if let annotations = annotationLookup[file.relativePath] {
                entry["annotations"] = annotations
            }

            filesPayload.append(entry)
        }

        var reviewMeta: [String: String]?
        if let g = guide?.reviewGuide {
            var meta: [String: String] = ["title": g.title]
            if !g.summary.isEmpty { meta["summary"] = g.summary }
            reviewMeta = meta
        }

        return (filesPayload, reviewMeta)
    }
}
