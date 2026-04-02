// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Native Form layout with project info, repo status, and workstream list.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onArchiveWorkstream: (UUID) -> Void
    let onProjectChanged: () -> Void

    @EnvironmentObject var appEnv: AppEnvironment
    @State private var worktrees: [WorktreeInfo] = []
    @State private var showingPruneConfirm = false
    @State private var isPruning = false

    @AppStorage("factoryfloor.defaultTerminal") private var defaultTerminal: String = ""
    @State private var docFiles: [DocFile] = []
    @State private var selectedDoc: String?
    @State private var selectedWorktreeForDetail: WorktreeInfo?
    @State private var showRepoChanges = false
    @State private var repoDetail: WorktreeDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (outside Form to avoid row styling)
            VStack(spacing: 4) {
                TextField("", text: $project.name)
                    .font(.system(size: 22, weight: .bold))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .onChange(of: project.name) { _, _ in onProjectChanged() }

                DirectoryRow(path: project.directory, defaultTerminal: defaultTerminal)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Form {
                // MARK: - Repository

                if let info = appEnv.repoInfo(for: project.directory) {
                    Section("Repository") {
                        if info.isRepo {
                            LabeledContent("Branch") {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)
                                    Text(info.branch ?? "unknown")
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let count = info.commitCount {
                                LabeledContent("Commits") {
                                    Text("\(count)")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let remote = info.remoteURL {
                                LabeledContent("Remote") {
                                    Text(remote)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            if info.isDirty {
                                LabeledContent("Status") {
                                    RepoStatusBadge(label: "Uncommitted changes", color: .orange) {
                                        showRepoChanges = true
                                        loadRepoDetail()
                                    }
                                    .popover(isPresented: $showRepoChanges) {
                                        RepoChangesPopover(detail: repoDetail, directory: project.directory) {
                                            showRepoChanges = false
                                            repoDetail = nil
                                            appEnv.refreshRepoInfo(for: project.directory)
                                        }
                                    }
                                }
                            } else {
                                LabeledContent("Status") {
                                    Text("Clean")
                                        .foregroundStyle(.green)
                                }
                            }
                        } else {
                            LabeledContent("Status") {
                                Text("Not a git repository")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - GitHub

                if appEnv.ghAvailable, let ghInfo = appEnv.githubRepo(for: project.directory) {
                    Section("GitHub") {
                        LabeledContent("Repository") {
                            Text(ghInfo.name)
                                .foregroundStyle(.secondary)
                        }

                        if let desc = ghInfo.description, !desc.isEmpty {
                            LabeledContent("Description") {
                                Text(desc)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Stars") {
                            Text("\(ghInfo.stars)")
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Open Issues") {
                            Text("\(ghInfo.openIssues)")
                                .foregroundStyle(.secondary)
                        }

                        let prs = appEnv.githubPRs(for: project.directory)
                        if !prs.isEmpty {
                            LabeledContent("Open PRs") {
                                Text("\(prs.count)")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(prs, id: \.number) { pr in
                                LabeledContent("#\(pr.number)") {
                                    Text(pr.title)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }

                // MARK: - Worktrees

                if !worktrees.isEmpty {
                    Section {
                        ForEach(worktrees) { wt in
                            let isArchiving = WorkstreamArchiver.archivingPaths.contains(
                                URL(fileURLWithPath: wt.path).standardizedFileURL.path
                            )
                            if wt.isMain || isArchiving {
                                WorktreeInfoRow(worktree: wt, isArchiving: isArchiving)
                            } else {
                                Button(action: { selectedWorktreeForDetail = wt }) {
                                    WorktreeInfoRow(worktree: wt)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if isPruning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Pruning...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if prunableCount > 0 {
                            Button(action: { showingPruneConfirm = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text(String(format: NSLocalizedString(prunableCount == 1 ? "Prune %d clean worktree" : "Prune %d clean worktrees", comment: ""), prunableCount))
                                }
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    } header: {
                        HStack {
                            Text("Git Worktrees")
                            Spacer()
                            Text("\(worktrees.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Worktrees on disk for this repository. Pruning removes clean worktrees and their associated workstreams.")
                    }
                }
            }
            .formStyle(.grouped)

            // Doc tabs
            if !docFiles.isEmpty {
                Divider()
                HStack(spacing: 0) {
                    ForEach(docFiles) { doc in
                        DocTabButton(
                            name: doc.name,
                            isActive: selectedDoc == doc.name,
                            action: { selectedDoc = doc.name }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                Divider()

                if let selected = selectedDoc,
                   let doc = docFiles.first(where: { $0.name == selected })
                {
                    MarkdownContentView(markdown: doc.content)
                        .id(selected)
                }
            }
        } // VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appEnv.refreshRepoInfo(for: project.directory)
            appEnv.refreshGitHubInfo(for: project.directory)
            refreshWorktrees()
            loadDocFiles()
        }
        .onChange(of: project.id) { _, _ in
            appEnv.refreshRepoInfo(for: project.directory)
            appEnv.refreshGitHubInfo(for: project.directory)
            worktrees = []
            docFiles = []
            selectedDoc = nil
            refreshWorktrees()
            loadDocFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: WorkstreamArchiver.archivingDidComplete)) { _ in
            refreshWorktrees()
        }
        .popover(item: $selectedWorktreeForDetail, arrowEdge: .trailing) { wt in
            WorktreeDetailSheet(
                worktree: wt,
                projectDirectory: project.directory,
                defaultTerminal: defaultTerminal
            ) {
                // Remove associated workstream if any
                if let idx = project.workstreams.firstIndex(where: { $0.worktreePath == wt.path }) {
                    project.workstreams.remove(at: idx)
                }
                onProjectChanged()
                refreshWorktrees()
            }
        }
        .alert("Prune Worktrees", isPresented: $showingPruneConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Prune", role: .destructive) { pruneWorktrees() }
        } message: {
            Text(String(format: NSLocalizedString(prunableCount == 1 ? "Remove %d worktree with no uncommitted changes? Associated workstreams will also be removed from the sidebar." : "Remove %d worktrees with no uncommitted changes? Associated workstreams will also be removed from the sidebar.", comment: ""), prunableCount))
        }
    }

    private var prunableCount: Int {
        worktrees.filter { wt in
            !wt.isMain && !wt.isDirty
                && !WorkstreamArchiver.archivingPaths.contains(URL(fileURLWithPath: wt.path).standardizedFileURL.path)
        }.count
    }

    private func loadRepoDetail() {
        let dir = project.directory
        repoDetail = nil
        Task.detached {
            let result = GitOperations.worktreeDetail(at: dir, mainRepoPath: dir)
            await MainActor.run { repoDetail = result }
        }
    }

    private func refreshWorktrees() {
        let dir = project.directory
        Task.detached {
            let wts = GitOperations.listWorktreesWithInfo(at: dir)
            await updateWorktrees(wts)
        }
    }

    private func loadDocFiles() {
        let dir = project.directory
        Task.detached {
            let found = DocFile.loadFrom(directory: dir)
            await updateDocFiles(found)
        }
    }

    private func pruneWorktrees() {
        isPruning = true
        let dir = project.directory
        let prunablePaths = Set(worktrees.filter { !$0.isMain && !$0.isDirty }.map(\.path))
        Task.detached {
            GitOperations.pruneCleanWorktrees(at: dir)
            await applyPrunedWorktrees(prunablePaths)
        }
    }

    @MainActor
    private func updateWorktrees(_ worktrees: [WorktreeInfo]) {
        self.worktrees = worktrees
    }

    @MainActor
    private func updateDocFiles(_ docFiles: [DocFile]) {
        self.docFiles = docFiles
        selectedDoc = docFiles.first?.name
    }

    @MainActor
    private func applyPrunedWorktrees(_ prunablePaths: Set<String>) {
        project.workstreams.removeAll { ws in
            guard let path = ws.worktreePath else { return false }
            return prunablePaths.contains(path)
        }
        onProjectChanged()
        isPruning = false
        refreshWorktrees()
    }
}

private struct WorktreeInfoRow: View {
    let worktree: WorktreeInfo
    var isArchiving: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: worktree.isMain ? "folder.fill" : "arrow.triangle.branch")
                .foregroundStyle(worktree.isMain ? .blue : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.branch ?? "detached")
                    .font(.system(.body, design: .monospaced))
                Text(worktree.path.abbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isArchiving {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Archiving...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
            } else if worktree.isMain {
                Text("main")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if worktree.isDirty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("Uncommitted changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovering ? Color.orange.opacity(0.15) : .clear)
                )
            } else {
                Text("Clean")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovering ? Color.green.opacity(0.15) : .clear)
                    )
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if !worktree.isMain && !isArchiving {
                isHovering = hovering
            }
        }
    }
}

private struct RepoStatusBadge: View {
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? color.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct RepoChangesPopover: View {
    let detail: WorktreeDetail?
    let directory: String
    let onDiscarded: () -> Void

    @State private var showDiscardConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let detail, !detail.changes.isEmpty {
                Text("Uncommitted Changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                ForEach(detail.changes) { change in
                    FileChangeRow(change: change, directory: directory)
                }

                Divider()
                    .padding(.top, 8)

                Button(role: .destructive, action: { showDiscardConfirm = true }) {
                    Label("Discard All Changes", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .alert("Discard All Changes", isPresented: $showDiscardConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Discard", role: .destructive) { discardAll() }
                } message: {
                    Text("This will permanently discard all uncommitted changes, including staged files and untracked files.")
                }
            } else if detail != nil {
                Text("No changes found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ProgressView()
                    .padding(16)
            }
        }
        .frame(minWidth: 300, maxWidth: 450)
    }

    private func discardAll() {
        let dir = directory
        Task.detached {
            GitOperations.discardAllChanges(at: dir)
            await MainActor.run { onDiscarded() }
        }
    }
}

private struct FileChangeRow: View {
    let change: WorktreeDetail.FileChange
    let directory: String

    @State private var isHovering = false

    var body: some View {
        Button(action: { openFile() }) {
            HStack(spacing: 8) {
                Image(systemName: change.status.icon)
                    .font(.caption)
                    .foregroundStyle(change.isStaged ? .green : .orange)
                    .frame(width: 14)
                Text(change.path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if change.isStaged {
                    Text("staged")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.accentColor.opacity(0.1) : .clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private func openFile() {
        let fullPath = URL(fileURLWithPath: directory)
            .appendingPathComponent(change.path).path

        if let nvimPath = CommandLineTools.path(for: "nvim") {
            openInTerminalWithNvim(nvimPath: nvimPath, filePath: fullPath)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
        }
    }

    private func openInTerminalWithNvim(nvimPath: String, filePath: String) {
        let escaped = filePath.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "\(nvimPath) '\(escaped)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

