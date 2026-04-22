import SwiftUI

struct GitDiffSheet: View {
    let session: Session
    let change: GitChange
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var lines: [GitDiffLine] = []
    @State private var truncatedFromLines: Int?
    @State private var isLoading = true
    @State private var isFullLoading = false

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        GitDiffSheetLine(line: line)
                    }
                    if let truncated = truncatedFromLines {
                        truncatedFooter(total: truncated)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.palette.background)
            .overlay {
                if isLoading { ProgressView() }
            }
            .navigationTitle(change.path)
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
            .task { await load(full: false) }
        }
        .presentationBackground(theme.palette.background)
        .preferredColorScheme(theme.palette.colorScheme)
    }

    private func truncatedFooter(total: Int) -> some View {
        VStack(spacing: ThemeTokens.Spacing.s) {
            Text("Diff truncated — \(total) lines")
                .appFont(size: ThemeTokens.Text.s)
                .foregroundColor(.secondary)
            Button {
                Task { await load(full: true) }
            } label: {
                if isFullLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Load full diff")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeTokens.Spacing.l)
    }

    private func load(full: Bool) async {
        if full { isFullLoading = true }
        guard let endpoint = session.endpoint, let path = session.path else {
            isLoading = false
            isFullLoading = false
            return
        }
        let result = await GitService.diff(
            endpoint: endpoint, session: session, path: path,
            file: change.path, staged: change.isStaged, full: full
        )
        if let result {
            lines = GitDiffParser.parse(result.text)
            truncatedFromLines = full ? nil : result.truncatedFromLines
        }
        isLoading = false
        isFullLoading = false
    }
}
