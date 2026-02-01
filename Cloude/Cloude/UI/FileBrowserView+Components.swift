import SwiftUI
import CloudeShared

struct PathComponent: Identifiable {
    var id: String { path }
    let name: String
    let path: String
}

extension FileBrowserView {
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
        .background(Color.oceanSecondary)
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

struct FileRow: View {
    let entry: FileEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: entry.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !entry.isDirectory {
                            Text(entry.formattedSize)
                        }
                        Text(entry.modified, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if entry.isDirectory {
            return .blue
        } else if entry.isImage {
            return .green
        } else if entry.isVideo {
            return .purple
        } else {
            return .secondary
        }
    }
}
