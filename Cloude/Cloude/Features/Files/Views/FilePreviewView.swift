import SwiftUI
import CloudeShared
import HighlightSwift

struct FilePreviewView: View {
    let path: String
    let environmentStore: EnvironmentStore
    var environmentId: UUID?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let fileEntry: FileEntry?

    @State var loadPhase: FileLoadPhase = .loading
    @State var viewMode: FileViewMode = .rendered
    @State var diff: DiffState = .hidden
    @State var fileData: Data?
    @State var highlightedCode: AttributedString?
    @AppStorage("wrapCodeLines") var wrapCodeLines = true
    @State var chunkProgress: (current: Int, total: Int)?
    @State var diffRequest: GitDiffCacheKey?

    init(file: FileEntry, environmentStore: EnvironmentStore, environmentId: UUID? = nil) {
        self.path = file.path
        self.fileEntry = file
        self.environmentStore = environmentStore
        self.environmentId = environmentId
    }

    init(path: String, environmentStore: EnvironmentStore, environmentId: UUID? = nil) {
        self.path = path
        self.fileEntry = nil
        self.environmentStore = environmentStore
        self.environmentId = environmentId
    }

    var fileName: String { path.lastPathComponent }
    var fileExtension: String { path.pathExtension.lowercased() }
    var contentType: FileContentType { .from(extension: fileExtension) }

    var connection: EnvironmentConnection? {
        environmentStore.connection(for: environmentId)
    }

    var currentFileResponse: LoadedFileState? {
        connection?.fileResponse(for: path)
    }

    var currentDirectoryListing: [FileEntry]? {
        connection?.directoryListing(for: path)
    }

    var currentPathError: String? {
        connection?.pathError(for: path)
    }

    var currentDiffText: String? {
        if let diffRequest {
            return connection?.gitDiffText(repoPath: diffRequest.repoPath, file: diffRequest.filePath, staged: diffRequest.staged)
        }
        return nil
    }

    var currentDiffError: String? {
        if let diffRequest {
            return connection?.gitDiffError(repoPath: diffRequest.repoPath, file: diffRequest.filePath, staged: diffRequest.staged)
        }
        return nil
    }

    var body: some View {
        Group {
            if let connection {
                EnvironmentConnectionObserver(connection: connection) { _ in
                    screen
                }
            } else {
                screen
            }
        }
    }

    private var screen: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FileViewerBreadcrumb(path: path, environmentSymbol: connection?.symbol)
                Divider()
                content
                Spacer(minLength: 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: DS.Spacing.m) {
                        if contentType.isTextBased, let _ = fileData {
                            Button(action: { toggleDiff() }) {
                                Image(systemName: diff != .hidden ? "doc.text" : "chevron.left.forwardslash.chevron.right")
                                    .foregroundStyle(diff != .hidden ? .accent : .primary)
                            }
                            .agenticID("file_preview_toggle_diff_button")
                            Divider()
                                .frame(height: DS.Icon.m)
                            Button(action: { wrapCodeLines.toggle() }) {
                                Image(systemName: wrapCodeLines ? "text.word.spacing" : "arrow.left.and.right.text.vertical")
                            }
                            .agenticID("file_preview_wrap_lines_button")
                        }
                        if contentType.hasRenderedView && fileData != nil {
                            Divider()
                                .frame(height: DS.Icon.m)
                            Button(action: { viewMode = (viewMode == .source) ? .rendered : .source }) {
                                Image(systemName: viewMode == .source ? "doc.richtext" : "curlybraces")
                            }
                            .agenticID("file_preview_toggle_source_button")
                        }
                    }
                    .font(.system(size: DS.Icon.s, weight: .medium))
                    .padding(.horizontal, DS.Spacing.l)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .agenticID("file_preview_close_button")
                    .font(.system(size: DS.Icon.s, weight: .medium))
                }
            }
        }
        .agenticID("file_preview_view")
        .onAppear { loadFile(); syncLoadedPath(); syncDiff() }
        .onChange(of: currentFileResponse) { _, _ in syncLoadedPath() }
        .onChange(of: currentDirectoryListing) { _, _ in syncLoadedPath() }
        .onChange(of: currentPathError) { _, _ in syncLoadedPath() }
        .onChange(of: currentDiffText) { _, _ in syncDiff() }
        .onChange(of: currentDiffError) { _, _ in syncDiff() }
    }

    func toggleDiff() {
        switch diff {
        case .hidden:
            diff = .loading
            let workDir = connection?.defaultWorkingDirectory ?? path.deletingLastPathComponent
            diffRequest = GitDiffCacheKey(repoPath: workDir, filePath: path, staged: false)
            connection?.gitDiff(path: workDir, file: path)
        case .loading, .loaded:
            diff = .hidden
            diffRequest = nil
        }
    }
}
