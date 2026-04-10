// ABOUTME: Changes tab showing worktree diff compared to the base branch.
// ABOUTME: Left panel lists changed files; right panel shows Monaco diff editor.

import SwiftUI

struct ChangesView: View {
    let workingDirectory: String
    let projectDirectory: String
    let bridge: MonacoEditorBridge

    @State private var changedFiles: [ChangedFile] = []
    @State private var selectedFile: ChangedFile?
    @State private var showUncommittedOnly = false
    @State private var isLoading = false
    @State private var showFileList = true
    @State private var mergeBaseRef: String?
    @State private var baseBranch: String = ""
    @State private var directoryWatcher: DirectoryWatcher?

    var body: some View {
        HStack(spacing: 0) {
            if showFileList {
                fileListPanel
                    .frame(width: 260)
                Divider()
            }
            VStack(spacing: 0) {
                changesToolbar
                diffPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadChanges()
            startWatcher()
        }
        .onDisappear {
            bridge.hideDiff()
            directoryWatcher?.stop()
            directoryWatcher = nil
        }
        .onChange(of: showUncommittedOnly) {
            Task { await loadChanges() }
        }
    }

    // MARK: - Toolbar

    private var changesToolbar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showFileList.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(showFileList ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle file list")

            if let file = selectedFile {
                Text((file.path as NSString).lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    // MARK: - File List Panel

    private var fileListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mode picker
            Picker("", selection: $showUncommittedOnly) {
                Text("All changes").tag(false)
                Text("Uncommitted").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(8)

            // Summary
            if !changedFiles.isEmpty {
                Text(String(format: NSLocalizedString("%d files changed", comment: ""), changedFiles.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            Divider()

            if isLoading && changedFiles.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No changes")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(changedFiles) { file in
                            changedFileRow(file)
                        }
                    }
                }
            }
        }
    }

    private func changedFileRow(_ file: ChangedFile) -> some View {
        let isSelected = selectedFile == file
        return Button {
            selectedFile = file
            Task { await loadDiff(for: file) }
        } label: {
            HStack(spacing: 6) {
                statusBadge(file.status)
                VStack(alignment: .leading, spacing: 1) {
                    Text((file.path as NSString).lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    let dir = (file.path as NSString).deletingLastPathComponent
                    if !dir.isEmpty {
                        Text(dir)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ status: ChangeStatus) -> some View {
        let (letter, color): (String, Color) = switch status {
        case .added: ("A", .green)
        case .modified: ("M", .orange)
        case .deleted: ("D", .red)
        case .renamed: ("R", .blue)
        }
        return Text(letter)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Diff Panel

    private var diffPanel: some View {
        ZStack {
            MonacoEditorView(bridge: bridge)
            if selectedFile == nil && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select a file to view changes")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
    }

    // MARK: - File Watching

    private func startWatcher() {
        guard directoryWatcher == nil else { return }
        directoryWatcher = DirectoryWatcher(path: workingDirectory) { [self] in
            Task { @MainActor in
                await refreshChanges()
            }
        }
    }

    /// Refresh file list and re-render the currently selected diff.
    private func refreshChanges() async {
        let projDir = projectDirectory
        let workDir = workingDirectory
        let uncommittedOnly = showUncommittedOnly
        let previousSelection = selectedFile

        let files: [ChangedFile]
        if uncommittedOnly {
            files = await Task.detached {
                GitOperations.uncommittedChangedFiles(at: workDir)
            }.value
        } else {
            // Reuse cached baseBranch/mergeBaseRef — they don't change within a session
            var ref = mergeBaseRef
            if ref == nil {
                let base = await Task.detached {
                    GitOperations.defaultBranch(at: projDir)
                }.value
                baseBranch = base
                ref = await Task.detached {
                    GitOperations.mergeBase(at: workDir, baseBranch: base)
                }.value
                mergeBaseRef = ref
            }

            let diffRef = ref ?? baseBranch
            files = await Task.detached {
                GitOperations.changedFiles(at: workDir, ref: diffRef)
            }.value
        }

        changedFiles = files

        // Keep the current selection if it still exists, otherwise select first
        if let prev = previousSelection, files.contains(prev) {
            await loadDiff(for: prev)
        } else if let first = files.first {
            selectedFile = first
            await loadDiff(for: first)
        } else {
            selectedFile = nil
            bridge.clearDiff()
        }
    }

    // MARK: - Data Loading

    func loadChanges() async {
        isLoading = true
        defer { isLoading = false }

        let projDir = projectDirectory
        let workDir = workingDirectory
        let uncommittedOnly = showUncommittedOnly

        let files: [ChangedFile]
        if uncommittedOnly {
            files = await Task.detached {
                GitOperations.uncommittedChangedFiles(at: workDir)
            }.value
        } else {
            let base = await Task.detached {
                GitOperations.defaultBranch(at: projDir)
            }.value
            baseBranch = base

            let ref = await Task.detached {
                GitOperations.mergeBase(at: workDir, baseBranch: base)
            }.value
            mergeBaseRef = ref

            let diffRef = ref ?? base
            files = await Task.detached {
                GitOperations.changedFiles(at: workDir, ref: diffRef)
            }.value
        }

        changedFiles = files

        // Auto-select first file
        if let first = files.first {
            selectedFile = first
            await loadDiff(for: first)
        } else {
            selectedFile = nil
            bridge.clearDiff()
        }
    }

    private func loadDiff(for file: ChangedFile) async {
        let ref = showUncommittedOnly ? "HEAD" : (mergeBaseRef ?? "HEAD")
        let workDir = workingDirectory

        let originalText: String
        let modifiedText: String

        switch file.status {
        case .added:
            originalText = ""
            modifiedText = readFileContent(file.path) ?? ""
        case .deleted:
            originalText = await Task.detached {
                GitOperations.fileContentAtRef(at: workDir, ref: ref, filePath: file.path)
            }.value ?? ""
            modifiedText = ""
        case .modified:
            originalText = await Task.detached {
                GitOperations.fileContentAtRef(at: workDir, ref: ref, filePath: file.path)
            }.value ?? ""
            modifiedText = readFileContent(file.path) ?? ""
        case let .renamed(from):
            originalText = await Task.detached {
                GitOperations.fileContentAtRef(at: workDir, ref: ref, filePath: from)
            }.value ?? ""
            modifiedText = readFileContent(file.path) ?? ""
        }

        let langId = EditorView.monacoLanguageId(for: (file.path as NSString).lastPathComponent)
        let fullPath = (workingDirectory as NSString).appendingPathComponent(file.path)
        bridge.showDiff(originalText: originalText, modifiedText: modifiedText, languageId: langId, filePath: fullPath)
    }

    private func readFileContent(_ relativePath: String) -> String? {
        let fullPath = (workingDirectory as NSString).appendingPathComponent(relativePath)
        return try? String(contentsOfFile: fullPath, encoding: .utf8)
    }
}
