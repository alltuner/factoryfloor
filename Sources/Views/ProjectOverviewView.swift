// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Native Form layout with project info, repo status, and workstream list.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onSelectWorkstream: (UUID) -> Void
    let onArchiveWorkstream: (UUID) -> Void
    let onProjectChanged: () -> Void

    @EnvironmentObject var appEnv: AppEnvironment
    @AppStorage("factoryfloor.workstreamSortOrder") private var workstreamSortOrder: ProjectSortOrder = .recent
    @State private var worktrees: [WorktreeInfo] = []
    @State private var showingPruneConfirm = false
    @State private var isPruning = false

    @AppStorage("factoryfloor.defaultTerminal") private var defaultTerminal: String = ""
    @State private var docFiles: [DocFile] = []
    @State private var selectedDoc: String?

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

                            LabeledContent("Status") {
                                Text(info.isDirty ? "Uncommitted changes" : "Clean")
                                    .foregroundStyle(info.isDirty ? .orange : .green)
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
                                LabeledContent {
                                    Text(pr.title)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                } label: {
                                    Text(verbatim: "#\(pr.number)")
                                }
                            }
                        }
                    }
                }

                // MARK: - Workstreams

                Section {
                    if project.workstreams.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("No workstreams yet")
                                    .foregroundStyle(.secondary)
                                (Text("Press ") + Text(Image(systemName: "command")) + Text(" N ") + Text("to create one."))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        let sorted = sortedWorkstreams(project.workstreams)
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, workstream in
                            WorkstreamRow(
                                workstream: workstream,
                                shortcutNumber: index < 9 ? index + 1 : nil,
                                onSelect: { onSelectWorkstream(workstream.id) },
                                onArchive: { onArchiveWorkstream(workstream.id) }
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Workstreams")
                        Spacer()
                        if project.workstreams.count > 1 {
                            Picker("", selection: $workstreamSortOrder) {
                                ForEach(ProjectSortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                        Text("\(project.workstreams.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Worktrees

                if !worktrees.isEmpty {
                    Section {
                        ForEach(worktrees) { wt in
                            WorktreeInfoRow(worktree: wt)
                        }

                        if prunableCount > 0 {
                            Button(action: { showingPruneConfirm = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text(String(format: NSLocalizedString(prunableCount == 1 ? "Prune %d clean worktree" : "Prune %d clean worktrees", comment: ""), prunableCount))
                                }
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .disabled(isPruning)
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
        .alert("Prune Worktrees", isPresented: $showingPruneConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Prune", role: .destructive) { pruneWorktrees() }
        } message: {
            Text(String(format: NSLocalizedString(prunableCount == 1 ? "Remove %d worktree with no uncommitted changes? Associated workstreams will also be removed from the sidebar." : "Remove %d worktrees with no uncommitted changes? Associated workstreams will also be removed from the sidebar.", comment: ""), prunableCount))
        }
    }

    private var prunableCount: Int {
        worktrees.filter { !$0.isMain && !$0.isDirty }.count
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

    private func sortedWorkstreams(_ workstreams: [Workstream]) -> [Workstream] {
        switch workstreamSortOrder {
        case .recent:
            return workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
        case .alphabetical:
            return workstreams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
            if worktree.isMain {
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
            } else {
                Text("Clean")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct WorkstreamRow: View {
    let workstream: Workstream
    var shortcutNumber: Int?
    let onSelect: () -> Void
    let onArchive: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workstream.name)
                        .font(.system(.body, design: .monospaced))
                    if let path = workstream.worktreePath {
                        Text(path.abbreviatedPath)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(minHeight: 36, alignment: .leading)
                Spacer()
                if let n = shortcutNumber {
                    Text("\(Image(systemName: "control"))\(n)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                Button(action: {
                    // Stop propagation to parent button
                    onArchive()
                }) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
            }
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
