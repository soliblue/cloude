import SwiftUI
import CloudeShared

extension FileBrowserView {
    var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(pathComponents, id: \.path) { component in
                    Button(action: { navigateTo(component.path) }) {
                        HStack(spacing: DS.Spacing.xs) {
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
            .padding(.vertical, DS.Spacing.s)
        }
        .background(Color.themeSecondary)
    }

    var pathComponents: [DirectoryPathComponent] {
        currentPath.directoryPathComponents
    }
}

struct FileRow: View {
    let entry: FileEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: entry.isDirectory ? "folder.fill" : fileIconName(for: entry.name))
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(entry.isDirectory ? AppColor.blue : fileIconColor(for: entry.name))

                HStack {
                    Text(entry.name)
                        .font(.system(size: DS.Text.m))
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: DS.Spacing.s) {
                        if !entry.isDirectory {
                            Text(entry.formattedSize)
                                .font(.system(size: DS.Text.s))
                        }
                        Text(entry.modified, style: .date)
                            .font(.system(size: DS.Text.s))
                    }
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
