import SwiftUI
import CloudeShared

extension FolderPickerView {
    var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pathComponents, id: \.path) { component in
                    Button(action: { navigateTo(component.path) }) {
                        HStack(spacing: 2) {
                            Text(component.name)
                                .font(.system(size: DS.Text.s))
                            if component.path != currentPath {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: DS.Text.s))
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
        .background(Color.themeSecondary)
    }

    var pathComponents: [PathComponent] {
        var components: [PathComponent] = []
        var path = currentPath

        while path != "/" && !path.isEmpty {
            let name = path.lastPathComponent
            components.insert(PathComponent(name: name, path: path), at: 0)
            path = path.deletingLastPathComponent
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
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.blue)
                    .frame(width: 32)

                Text(entry.name)
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
