import SwiftUI
import CloudeShared

private let maxComponentLength = 20

struct FileViewerBreadcrumb: View {
    let path: String
    var environmentSymbol: String? = nil
    let onNavigate: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    if let symbol = environmentSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }
                    ForEach(components) { component in
                        if component.path.isEmpty {
                            Text(component.name)
                                .font(.system(size: DS.Text.s))
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: { onNavigate(component.path) }) {
                                Text(component.name)
                                    .font(.system(size: DS.Text.s))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .id(component.path)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }

                    Text(fileName)
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.primary)
                        .id("current-file")
                }
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.s)
            }
            .onAppear {
                proxy.scrollTo("current-file", anchor: .trailing)
            }
        }
        .background(Color.themeSecondary)
    }

    private var fileName: String {
        path.lastPathComponent.truncatedMiddle
    }

    private var parentPath: String {
        path.deletingLastPathComponent
    }

    private var components: [PathComponent] {
        var result: [PathComponent] = []
        var current = parentPath

        while current != "/" && !current.isEmpty {
            let name = current.lastPathComponent.truncatedBreadcrumb
            result.insert(PathComponent(name: name, path: current), at: 0)
            current = current.deletingLastPathComponent
        }
        result.insert(PathComponent(name: "/", path: "/"), at: 0)

        if result.count > 4 {
            let first = Array(result.prefix(1))
            let last2 = Array(result.suffix(2))
            return first + [PathComponent(name: "…", path: "")] + last2
        }

        return result
    }
}


private extension String {
    var truncatedBreadcrumb: String {
        count <= maxComponentLength ? self : String(prefix(maxComponentLength - 1)) + "…"
    }

    var truncatedMiddle: String {
        guard count > maxComponentLength else { return self }
        let ext = (self as NSString).pathExtension
        let name = (self as NSString).deletingPathExtension
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        let available = maxComponentLength - suffix.count - 1
        return String(name.prefix(available)) + "…" + suffix
    }
}
