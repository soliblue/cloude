import SwiftUI

struct FileTreeSheetSearchResults: View {
    let session: Session
    let query: String
    @Environment(\.theme) private var theme
    @State private var results: [FileNodeDTO] = []
    @State private var searched = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                ForEach(results, id: \.path) { node in
                    NavigationLink(value: node) {
                        rowLabel(node)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.s)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background)
        .overlay {
            if searched && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            if let endpoint = session.endpoint, let path = session.path, !path.isEmpty {
                let files = await FilesService.search(
                    endpoint: endpoint, session: session, root: path, query: query)
                if Task.isCancelled { return }
                results = (files ?? []).filter { !$0.isDirectory }
                searched = true
            }
        }
    }

    private func rowLabel(_ node: FileNodeDTO) -> some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Image(systemName: "doc")
                .appFont(size: ThemeTokens.Icon.m)
                .foregroundColor(ThemeColor.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(node.name)
                    .appFont(size: ThemeTokens.Text.m)
                    .lineLimit(1)
                    .foregroundColor(theme.palette.colorScheme == .dark ? .white : .black)
                let directory = relativeDirectory(node)
                if !directory.isEmpty {
                    Text(directory)
                        .appFont(size: ThemeTokens.Text.s)
                        .lineLimit(1)
                        .foregroundColor(ThemeColor.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .contentShape(Rectangle())
    }

    private func relativeDirectory(_ node: FileNodeDTO) -> String {
        let directory = (node.path as NSString).deletingLastPathComponent
        if let root = session.path, directory.hasPrefix(root) {
            return String(directory.dropFirst(root.count)).trimmingCharacters(
                in: CharacterSet(charactersIn: "/"))
        }
        return directory
    }
}
