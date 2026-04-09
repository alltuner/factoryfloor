// ABOUTME: SwiftUI view that renders a nested file tree with selection support.
// ABOUTME: Directories are always expanded; files are clickable to open in the editor.

import SwiftUI

struct FileTreeView: View {
    let nodes: [FileNode]
    let selectedPath: String?
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(nodes) { node in
                    FileTreeNodeView(node: node, depth: 0, selectedPath: selectedPath, onSelect: onSelect)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct FileTreeNodeView: View {
    let node: FileNode
    let depth: Int
    let selectedPath: String?
    var onSelect: (String) -> Void

    var body: some View {
        if node.isDirectory {
            directoryRow
            ForEach(node.children) { child in
                FileTreeNodeView(node: child, depth: depth + 1, selectedPath: selectedPath, onSelect: onSelect)
            }
        } else {
            fileRow
        }
    }

    private var directoryRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Text(node.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, CGFloat(depth) * 16 + 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileRow: some View {
        let isSelected = node.id == selectedPath

        return Button {
            onSelect(node.id)
        } label: {
            Text(node.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(depth) * 16 + 8)
                .padding(.vertical, 3)
                .padding(.trailing, 8)
                .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
