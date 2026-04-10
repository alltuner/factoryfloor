// ABOUTME: SwiftUI view that renders a nested file tree with togglable folders and selection support.
// ABOUTME: Shows file-type icons, git status colors, and reduced opacity for gitignored entries.

import SwiftUI

struct FileTreeView: View {
    let nodes: [FileNode]
    let selectedPath: String?
    let gitStatus: GitFileStatusProvider
    var onSelect: (String) -> Void
    var onExpandFolder: (String) -> Void

    @State private var expandedFolders: Set<String> = []

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nodes) { node in
                        FileTreeNodeView(
                            node: node,
                            depth: 0,
                            selectedPath: selectedPath,
                            gitStatus: gitStatus,
                            expandedFolders: $expandedFolders,
                            onSelect: onSelect,
                            onExpandFolder: onExpandFolder
                        )
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .onAppear {
            expandAncestors(of: selectedPath)
        }
        .onChange(of: selectedPath) { _, newPath in
            expandAncestors(of: newPath)
        }
    }

    /// Expand all ancestor folders so a selected file is visible in the tree.
    /// Also triggers lazy loading for any unloaded ancestor directories.
    private func expandAncestors(of path: String?) {
        guard let path, !path.isEmpty else { return }
        let components = path.split(separator: "/").map(String.init)
        var current = ""
        for component in components.dropLast() {
            current = current.isEmpty ? component : current + "/" + component
            onExpandFolder(current)
            expandedFolders.insert(current)
        }
    }
}

// MARK: - Git status colors (VSCode conventions)

private let modifiedColor = Color(red: 0.886, green: 0.753, blue: 0.553) // #E2C08D
private let untrackedColor = Color(red: 0.451, green: 0.788, blue: 0.569) // #73C991

private func gitTextColor(for status: FileGitStatus?) -> Color {
    switch status {
    case .modified: return modifiedColor
    case .untracked: return untrackedColor
    case .ignored, .none: return .primary
    }
}

// MARK: - Node View

private struct FileTreeNodeView: View {
    let node: FileNode
    let depth: Int
    let selectedPath: String?
    let gitStatus: GitFileStatusProvider
    @Binding var expandedFolders: Set<String>
    var onSelect: (String) -> Void
    var onExpandFolder: (String) -> Void

    private var isExpanded: Bool {
        expandedFolders.contains(node.id)
    }

    private var isIgnored: Bool {
        gitStatus.isIgnored(node.id)
    }

    var body: some View {
        if node.isDirectory {
            directoryRow
            if isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeView(
                        node: child,
                        depth: depth + 1,
                        selectedPath: selectedPath,
                        gitStatus: gitStatus,
                        expandedFolders: $expandedFolders,
                        onSelect: onSelect,
                        onExpandFolder: onExpandFolder
                    )
                }
            }
        } else {
            fileRow
        }
    }

    private var directoryRow: some View {
        let dirStatus = gitStatus.status(for: node.id, isDirectory: true)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isExpanded {
                    expandedFolders.remove(node.id)
                } else {
                    if !node.isLoaded {
                        onExpandFolder(node.id)
                    }
                    expandedFolders.insert(node.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(gitTextColor(for: dirStatus))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(isIgnored ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var fileRow: some View {
        let isSelected = node.id == selectedPath
        let fileStatus = gitStatus.status(for: node.id, isDirectory: false)
        let icon = FileTypeIcon.icon(for: node.name)

        return Button {
            onSelect(node.id)
        } label: {
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 10, height: 1)
                Image(systemName: icon.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundStyle(gitTextColor(for: fileStatus))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .cornerRadius(4)
            .opacity(isIgnored ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
