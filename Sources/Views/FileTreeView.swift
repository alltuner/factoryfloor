// ABOUTME: SwiftUI view that renders a nested file tree with togglable folders and selection support.
// ABOUTME: Folders expand/collapse on click; horizontal scrolling for long paths.

import SwiftUI

struct FileTreeView: View {
    let nodes: [FileNode]
    let selectedPath: String?
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

private struct FileTreeNodeView: View {
    let node: FileNode
    let depth: Int
    let selectedPath: String?
    @Binding var expandedFolders: Set<String>
    var onSelect: (String) -> Void
    var onExpandFolder: (String) -> Void

    private var isExpanded: Bool {
        expandedFolders.contains(node.id)
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
        Button {
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
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fileRow: some View {
        let isSelected = node.id == selectedPath

        return Button {
            onSelect(node.id)
        } label: {
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 10, height: 1)
                Image(systemName: "doc")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
