import SwiftUI
import CloudeShared

private let maxComponentLength = 20

struct FileViewerBreadcrumb: View {
    let path: String
    let onNavigate: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(components) { component in
                        if component.path.isEmpty {
                            Text(component.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: { onNavigate(component.path) }) {
                                Text(component.name)
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .id(component.path)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }

                    Text(fileName)
                        .font(.caption2.bold())
                        .foregroundColor(.primary)
                        .id("current-file")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onAppear {
                proxy.scrollTo("current-file", anchor: .trailing)
            }
        }
        .background(Color.oceanSecondary)
    }

    private var fileName: String {
        path.lastPathComponent.truncatedBreadcrumb
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

struct FileViewerActions: View {
    let path: String
    let fileData: Data?
    let isCodeFile: Bool
    let onGitDiff: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let data = fileData {
                ShareLink(item: data, preview: SharePreview(fileName)) {
                    Image(systemName: "square.and.arrow.up")
                }

                Divider()
                    .frame(height: 20)

                Button(action: { copyToClipboard(data) }) {
                    Image(systemName: "doc.on.doc")
                }
            }

            if isCodeFile, let onGitDiff {
                Divider()
                    .frame(height: 20)

                Button(action: onGitDiff) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .padding(.horizontal, 12)
        .font(.body)
    }

    private var fileName: String {
        path.lastPathComponent
    }

    private func copyToClipboard(_ data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = text
        } else {
            UIPasteboard.general.setData(data, forPasteboardType: "public.data")
        }
    }
}

private extension String {
    var truncatedBreadcrumb: String {
        count <= maxComponentLength ? self : String(prefix(maxComponentLength - 1)) + "…"
    }
}
