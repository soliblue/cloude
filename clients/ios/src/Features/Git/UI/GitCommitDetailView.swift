import SwiftUI

struct GitCommitDetailView: View {
    let session: Session
    let sha: String
    let subject: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var detail: GitCommitDetailDTO?
    @State private var parsedFiles: [ParsedFile] = []
    @State private var isLoading = true

    private struct ParsedFile: Identifiable {
        let path: String
        let language: String
        let lines: [GitDiffLine]
        var id: String { path }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if let detail {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        header(detail)
                        ForEach(parsedFiles) { file in
                            fileSection(file)
                        }
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if !isLoading {
                    ContentUnavailableView(
                        "Commit unavailable", systemImage: "exclamationmark.triangle",
                        description: Text("Couldn't load this commit."))
                        .padding(.top, ThemeTokens.Spacing.xl)
                }
            }
            .background(theme.palette.background)
            .overlay {
                if isLoading { ProgressView() }
            }
            .navigationTitle(String(sha.prefix(9)))
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
            .task { await load() }
        }
        .presentationBackground(theme.palette.background)
        .preferredColorScheme(theme.palette.colorScheme)
    }

    private func header(_ detail: GitCommitDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Text(detail.subject.isEmpty ? subject : detail.subject)
                .appFont(size: ThemeTokens.Text.l, weight: .semibold)
            if !detail.body.isEmpty {
                Text(detail.body)
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
            Text("\(detail.author) · \(String(sha.prefix(9)))")
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundColor(.secondary)
            if !detail.files.isEmpty {
                Text("\(detail.files.count) file\(detail.files.count == 1 ? "" : "s") changed")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ThemeTokens.Spacing.l)
    }

    private func fileSection(_ file: ParsedFile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(file.path)
                .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                .foregroundColor(.secondary)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface)
            ForEach(file.lines) { line in
                GitDiffSheetLine(line: line, language: file.language)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }

    private func load() async {
        if let endpoint = session.endpoint, let path = session.path {
            let loaded = await GitService.commitDetail(
                endpoint: endpoint, session: session, path: path, sha: sha)
            detail = loaded
            parsedFiles = GitDiffParser.splitByFile(loaded?.diff ?? "").map {
                ParsedFile(
                    path: $0.path,
                    language: FilePreviewContentType.detect(path: $0.path).sourceLanguage,
                    lines: GitDiffParser.parse($0.text))
            }
        }
        isLoading = false
    }
}
