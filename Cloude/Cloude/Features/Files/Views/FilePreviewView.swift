import SwiftUI
import CloudeShared
import Combine
import HighlightSwift

struct FilePreviewView: View {
    let path: String
    let connection: ConnectionManager
    var environmentId: UUID?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let fileEntry: FileEntry?

    @State var loadPhase: FileLoadPhase = .loading
    @State var viewMode: FileViewMode = .rendered
    @State var diff: DiffState = .hidden
    @State var fileData: Data?
    @State var cancellables = Set<AnyCancellable>()
    @State var highlightedCode: AttributedString?
    @AppStorage("wrapCodeLines") var wrapCodeLines = true
    @State var chunkProgress: (current: Int, total: Int)?

    init(file: FileEntry, connection: ConnectionManager, environmentId: UUID? = nil) {
        self.path = file.path
        self.fileEntry = file
        self.connection = connection
        self.environmentId = environmentId
    }

    init(path: String, connection: ConnectionManager, environmentId: UUID? = nil) {
        self.path = path
        self.fileEntry = nil
        self.connection = connection
        self.environmentId = environmentId
    }

    var fileName: String { path.lastPathComponent }
    var fileExtension: String { path.pathExtension.lowercased() }
    var contentType: FileContentType { .from(extension: fileExtension) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FileViewerBreadcrumb(path: path, environmentSymbol: connection.connection(for: environmentId)?.symbol)
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
        .onAppear { loadFile() }
        .onReceive(connection.events) { event in
            if case let .gitDiff(_, text) = event, case .loading = diff {
                diff = .loaded(text)
            }
        }
    }

    func toggleDiff() {
        switch diff {
        case .hidden:
            diff = .loading
            let workDir = connection.connection(for: environmentId)?.defaultWorkingDirectory ?? path.deletingLastPathComponent
            connection.gitDiff(path: workDir, file: path, environmentId: environmentId)
        case .loading, .loaded:
            diff = .hidden
        }
    }
}
