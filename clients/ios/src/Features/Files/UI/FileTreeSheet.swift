import SwiftUI

struct FileTreeSheet: View {
    let session: Session
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    FileTreeView(session: session)
                } else {
                    FileTreeSheetSearchResults(session: session, query: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search files")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
            .navigationDestination(for: FileNodeDTO.self) { node in
                FilePreviewSheet(session: session, node: node, isPushed: true)
            }
        }
        .presentationBackground(theme.palette.background)
    }

    private var title: String {
        if let path = session.path, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return "Files"
    }
}
