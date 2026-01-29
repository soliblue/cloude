//
//  FolderPickerView+Components.swift
//  Cloude
//

import SwiftUI

extension FolderPickerView {
    var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pathComponents, id: \.path) { component in
                    Button(action: { navigateTo(component.path) }) {
                        HStack(spacing: 2) {
                            Text(component.name)
                                .font(.caption)
                            if component.path != currentPath {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(component.path == currentPath ? .primary : .accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    var pathComponents: [PathComponent] {
        var components: [PathComponent] = []
        var path = currentPath

        while path != "/" && !path.isEmpty {
            let name = (path as NSString).lastPathComponent
            components.insert(PathComponent(name: name, path: path), at: 0)
            path = (path as NSString).deletingLastPathComponent
        }
        components.insert(PathComponent(name: "/", path: "/"), at: 0)

        return components
    }
}

struct FolderRow: View {
    let entry: FileEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32)

                Text(entry.name)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
