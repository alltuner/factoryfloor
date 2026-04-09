// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Native Form layout with project info, repo status, and workstream list.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onSelectWorkstream: (UUID) -> Void
    let onRemoveWorkstream: (UUID) -> Void
    let onPurgeWorkstream: (UUID) -> Void
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

                DirectoryRow(path: project.directory, defaultTerminal: defaultTerminal, githubURL: appEnv.githubURL(for: project.directory))
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
                            Text("No workstreams yet")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        let sorted = sortedWorkstreams(project.workstreams)
                        ForEach(sorted) { workstream in
                            let branch = appEnv.branchName(for: workstream.worktreePath)
                            let pr = branch.flatMap { appEnv.githubPR(for: project.directory, branch: $0) }
                            WorkstreamRow(
                                workstream: workstream,
                                isPathValid: appEnv.isPathValid(workstream.worktreePath),
                                hasActivePort: appEnv.hasActivePort(workstream.id),
                                taskDescription: appEnv.taskDescription(for: workstream.worktreePath),
                                branchName: branch,
                                prTitle: pr?.title,
                                prNumber: pr?.number,
                                prState: pr?.state,
                                prURL: pr?.url,
                                onSelect: { onSelectWorkstream(workstream.id) },
                                onRemove: { onRemoveWorkstream(workstream.id) },
                                onPurge: { onPurgeWorkstream(workstream.id) }
                            )
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Workstreams")
                        if !project.workstreams.isEmpty {
                            Text("\(project.workstreams.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
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
                    }
                }

                // MARK: - Worktrees

                if !worktrees.isEmpty {
                    Section {
                        ForEach(worktrees) { wt in
                            WorktreeInfoRow(
                                worktree: wt,
                                projectDirectory: project.directory,
                                isWorkstream: workstreamPaths.contains(Self.standardizedPath(wt.path)),
                                onAdopt: { adoptWorktree(wt) }
                            )
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
                        Text("Worktrees on disk for this repository. Pruning removes clean worktrees that are not associated with a workstream.")
                    }
                }
            }
            .formStyle(.grouped)

            // Markdown content
            if let selected = selectedDoc,
               let doc = docFiles.first(where: { $0.name == selected })
            {
                Divider()
                MarkdownContentView(markdown: doc.content)
                    .id(selected)
            }

            // Doc tabs pinned to bottom
            if !docFiles.isEmpty {
                Divider()
                HStack(spacing: 0) {
                    ForEach(docFiles) { doc in
                        DocTabButton(
                            name: doc.name,
                            isActive: selectedDoc == doc.name,
                            action: { selectedDoc = selectedDoc == doc.name ? nil : doc.name }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
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
            Text(String(format: NSLocalizedString(prunableCount == 1 ? "Remove %d clean worktree with no uncommitted changes?" : "Remove %d clean worktrees with no uncommitted changes?", comment: ""), prunableCount))
        }
    }

    private var workstreamPaths: Set<String> {
        Set(project.workstreams.compactMap(\.worktreePath).map(Self.standardizedPath))
    }

    private var prunableWorktrees: [WorktreeInfo] {
        return worktrees.filter { worktree in
            guard !worktree.isMain && !worktree.isDirty && !worktree.hasBranchCommits else { return false }
            return !workstreamPaths.contains(Self.standardizedPath(worktree.path))
        }
    }

    private var prunablePaths: Set<String> {
        Set(prunableWorktrees.map(\.path).map(Self.standardizedPath))
    }

    private var prunableCount: Int {
        prunableWorktrees.count
    }

    private func adoptWorktree(_ worktree: WorktreeInfo) {
        let name = worktree.branch ?? worktree.path.components(separatedBy: "/").last ?? "workstream"
        let workstream = Workstream(name: name, worktreePath: worktree.path)
        NotificationCenter.default.post(
            name: .workstreamCreated,
            object: nil,
            userInfo: ["projectID": project.id, "workstream": workstream]
        )
    }

    private func refreshWorktrees() {
        let dir = project.directory
        Task.detached {
            let wts = GitOperations.listWorktreesWithInfo(at: dir)
            await updateWorktrees(wts)
            // Populate PR cache for worktree branches
            let branches = Set(wts.compactMap(\.branch))
            await MainActor.run {
                appEnv.refreshBranchPRs(for: dir, branches: branches)
            }
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
        let pathsToPrune = prunablePaths
        Task.detached {
            GitOperations.pruneCleanWorktrees(at: dir, onlyPaths: pathsToPrune)
            await applyPrunedWorktrees(pathsToPrune)
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
    }

    @MainActor
    private func applyPrunedWorktrees(_ prunablePaths: Set<String>) {
        project.workstreams.removeAll { ws in
            guard let path = ws.worktreePath else { return false }
            return prunablePaths.contains(Self.standardizedPath(path))
        }
        onProjectChanged()
        isPruning = false
        refreshWorktrees()
    }

    private static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private struct WorktreeInfoRow: View {
    let worktree: WorktreeInfo
    let projectDirectory: String
    let isWorkstream: Bool
    let onAdopt: () -> Void

    @EnvironmentObject var appEnv: AppEnvironment

    private var pr: GitHubPR? {
        guard let branch = worktree.branch else { return nil }
        return appEnv.githubPR(for: projectDirectory, branch: branch)
    }

    var body: some View {
        HStack {
            Image(systemName: worktree.isMain ? "folder.fill" : "arrow.triangle.branch")
                .foregroundStyle(worktree.isMain ? .blue : .secondary)
                .frame(width: 20, alignment: .top)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.branch ?? "detached")
                    .font(.system(.body, design: .monospaced))
                Text(worktree.path.abbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if !worktree.isMain {
                    HStack(spacing: 8) {
                        if let pr {
                            let prColor: Color = pr.state == "MERGED" ? .purple : .green
                            Link(destination: URL(string: pr.url)!) {
                                HStack(spacing: 3) {
                                    Image(systemName: pr.state == "MERGED" ? "arrow.triangle.merge" : "arrow.triangle.pull")
                                        .font(.system(size: 10))
                                    Text(verbatim: "#\(pr.number)")
                                        .font(.caption)
                                }
                                .foregroundStyle(prColor)
                            }
                        }
                        if worktree.isDirty {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                                Text("Uncommitted changes")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else if worktree.hasBranchCommits {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 10))
                                Text("Commits ahead")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        } else {
                            Text("Clean")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .frame(minHeight: 36, alignment: .leading)
            Spacer()
            if worktree.isMain {
                Text("main")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !isWorkstream {
                Button(action: onAdopt) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.rectangle.on.folder")
                            .font(.system(size: 12))
                        Text("Open")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WorkstreamRow: View {
    let workstream: Workstream
    var isPathValid: Bool = true
    var hasActivePort: Bool = false
    var taskDescription: String?
    var branchName: String?
    var prTitle: String?
    var prNumber: Int?
    var prState: String?
    var prURL: String?
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onPurge: () -> Void

    @State private var isHovering = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// The most descriptive label we have for this workstream.
    private var headline: String {
        if let prTitle { return prTitle }
        if let taskDescription { return taskDescription }
        return workstream.name
    }

    /// Whether the headline came from a description/PR (true) or is just the generated name (false).
    private var hasRichHeadline: Bool {
        prTitle != nil || taskDescription != nil
    }

    /// Secondary line: branch name when we have a rich headline, otherwise nil.
    private var subtitle: String? {
        guard isPathValid else { return nil }
        if hasRichHeadline {
            return branchName ?? workstream.name
        }
        if let branchName, branchName != workstream.name {
            return branchName
        }
        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if !isPathValid {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.system(size: 11))
                        }
                        Text(headline)
                            .font(.system(hasRichHeadline ? .body : .body, design: hasRichHeadline ? .default : .monospaced))
                            .strikethrough(!isPathValid)
                            .foregroundStyle(isPathValid ? .primary : .secondary)
                            .lineLimit(1)
                        if hasActivePort {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.green)
                        }
                        if let prNumber, let prState {
                            PRBadge(number: prNumber, state: prState, url: prURL)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 36, alignment: .leading)
                Spacer()
                Text(Self.relativeFormatter.localizedString(for: workstream.lastAccessedAt, relativeTo: Date()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button(action: onRemove) {
                    Image(systemName: "xmark")
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
        .contextMenu {
            if let worktreePath = workstream.worktreePath {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktreePath)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                Button {
                    openDirectoryInTerminal(worktreePath)
                } label: {
                    Label("Open in External Terminal", systemImage: "terminal")
                }
                Divider()
            }
            if let branchName {
                Button {
                    copyTextToPasteboard(branchName)
                } label: {
                    Label("Copy branch name", systemImage: "arrow.triangle.branch")
                }
            }
            Divider()
            Button(action: onRemove) {
                Label("Remove", systemImage: "xmark")
            }
            Button(role: .destructive, action: onPurge) {
                Label("Purge", systemImage: "trash")
            }
        }
    }
}

private struct PRBadge: View {
    let number: Int
    let state: String
    var url: String?

    private var color: Color {
        switch state {
        case "MERGED": return .purple
        case "CLOSED": return .red
        default: return .green
        }
    }

    private var icon: String {
        switch state {
        case "MERGED": return "arrow.triangle.merge"
        default: return "arrow.triangle.pull"
        }
    }

    var body: some View {
        let label = HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(verbatim: "#\(number)")
                .font(.system(size: 11))
        }
        .foregroundStyle(color)

        if let url, let dest = URL(string: url) {
            Link(destination: dest) { label }
        } else {
            label
        }
    }
}
