import SwiftUI

struct GitCommitDetailView: View {
    let session: Session
    let sha: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var parsedFiles: [ParsedFile] = []
    @State private var expandedFiles: Set<String> = []
    @State private var collapsedHunks: Set<String> = []
    @State private var loaded = false
    @State private var loadFailed = false

    private struct ParsedFile: Identifiable {
        let path: String
        let language: String
        let hunks: [GitDiffParser.DiffHunk]
        let additions: Int
        let deletions: Int
        var id: String { path }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if !parsedFiles.isEmpty {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        counter
                        ForEach(parsedFiles) { file in
                            fileSection(file)
                        }
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if loaded && loadFailed {
                    ContentUnavailableView(
                        "Commit unavailable", systemImage: "exclamationmark.triangle",
                        description: Text("Couldn't load this commit."))
                        .padding(.top, ThemeTokens.Spacing.xl)
                } else if loaded {
                    ContentUnavailableView(
                        "No file changes", systemImage: "doc",
                        description: Text("This commit has no diff."))
                        .padding(.top, ThemeTokens.Spacing.xl)
                }
            }
            .background(theme.palette.background)
            .overlay {
                if !loaded { ProgressView() }
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

    private var counter: some View {
        let files = parsedFiles.count
        let additions = parsedFiles.reduce(0) { $0 + $1.additions }
        let deletions = parsedFiles.reduce(0) { $0 + $1.deletions }
        return HStack(spacing: ThemeTokens.Spacing.s) {
            Text("\(files) file\(files == 1 ? "" : "s") changed")
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .foregroundColor(.secondary)
            Spacer()
            if additions > 0 {
                Text("+\(additions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.success)
            }
            if deletions > 0 {
                Text("-\(deletions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.danger)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.l)
    }

    private func fileSection(_ file: ParsedFile) -> some View {
        let isExpanded = expandedFiles.contains(file.path)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleFile(file.path)
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                        .foregroundStyle(.tertiary)
                        .frame(width: ThemeTokens.Spacing.m)
                    Text(file.path)
                        .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if file.additions > 0 {
                        Text("+\(file.additions)")
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundColor(ThemeColor.success)
                    }
                    if file.deletions > 0 {
                        Text("-\(file.deletions)")
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundColor(ThemeColor.danger)
                    }
                }
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                ForEach(file.hunks) { hunk in
                    hunkSection(file, hunk)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }

    @ViewBuilder
    private func hunkSection(_ file: ParsedFile, _ hunk: GitDiffParser.DiffHunk) -> some View {
        let isCollapsed = collapsedHunks.contains(hunk.id)
        if hunk.header.isEmpty {
            ForEach(hunk.lines) { line in
                GitDiffSheetLine(line: line, language: file.language)
            }
        } else {
            Button {
                toggleHunk(hunk.id)
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                        .foregroundStyle(.tertiary)
                        .frame(width: ThemeTokens.Spacing.m)
                    Text(hunk.header)
                        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, ThemeTokens.Spacing.s)
                .padding(.vertical, ThemeTokens.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemeColor.blue.opacity(ThemeTokens.Opacity.s))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !isCollapsed {
                ForEach(hunk.lines) { line in
                    GitDiffSheetLine(line: line, language: file.language)
                }
            }
        }
    }

    private func toggleFile(_ key: String) {
        if expandedFiles.contains(key) { expandedFiles.remove(key) } else { expandedFiles.insert(key) }
    }

    private func toggleHunk(_ key: String) {
        if collapsedHunks.contains(key) { collapsedHunks.remove(key) } else { collapsedHunks.insert(key) }
    }

    private func load() async {
        if let endpoint = session.endpoint, let path = session.path {
            let detail = await GitService.commitDetail(
                endpoint: endpoint, session: session, path: path, sha: sha)
            if let detail {
                parsedFiles = GitDiffParser.splitByFile(detail.diff).map { file in
                    let hunks = GitDiffParser.groupHunks(
                        GitDiffParser.parse(file.text), filePath: file.path)
                    return ParsedFile(
                        path: file.path,
                        language: FilePreviewContentType.detect(path: file.path).sourceLanguage,
                        hunks: hunks,
                        additions: hunks.reduce(0) { $0 + $1.additions },
                        deletions: hunks.reduce(0) { $0 + $1.deletions })
                }
            } else {
                loadFailed = true
            }
        } else {
            loadFailed = true
        }
        loaded = true
    }
}
