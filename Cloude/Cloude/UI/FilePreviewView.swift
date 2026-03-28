import SwiftUI
import CloudeShared
import Combine
import HighlightSwift

struct FilePreviewView: View {
    let path: String
    @ObservedObject var connection: ConnectionManager
    var environmentId: UUID?
    var onBrowseFolder: ((String) -> Void)?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let fileEntry: FileEntry?

    @State var isLoading = true
    @State var fileData: Data?
    @State var errorMessage: String?
    @State var isTruncated = false
    @State var loadProgress: (current: Int, total: Int)?
    @State var cancellables = Set<AnyCancellable>()
    @State var isThumbnail = false
    @State var fullSize: Int64 = 0
    @State var isLoadingFullQuality = false
    @State var showDiff = false
    @State var diffText: String?
    @State var isDiffLoading = false
    @State var highlightedCode: AttributedString?
    @State var directoryEntries: [FileEntry]?
    @State var browsingFolder: String?
    @State var showSource = false
    @AppStorage("wrapCodeLines") var wrapCodeLines = true
    @State var chunkProgress: (current: Int, total: Int)?

    init(file: FileEntry, connection: ConnectionManager, environmentId: UUID? = nil, onBrowseFolder: ((String) -> Void)? = nil) {
        self.path = file.path
        self.fileEntry = file
        self.connection = connection
        self.environmentId = environmentId
        self.onBrowseFolder = onBrowseFolder
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
                if let folder = browsingFolder {
                    FileBrowserView(connection: connection, rootPath: folder, environmentId: environmentId)
                } else {
                    FileViewerBreadcrumb(path: path, environmentSymbol: connection.connection(for: environmentId)?.symbol) { folderPath in
                        if fileEntry != nil {
                            dismiss()
                            onBrowseFolder?(folderPath)
                        } else {
                            browsingFolder = folderPath
                        }
                    }
                    Divider()
                    content
                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(browsingFolder != nil ? .hidden : .automatic, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                if browsingFolder != nil {
                    Button(action: { browsingFolder = nil }) {
                        Image(systemName: "doc.text")
                            .padding(DS.Spacing.m)
                    }
                    .agenticID("file_preview_back_to_file_button")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: DS.Spacing.m) {
                        if contentType.isTextBased, let _ = fileData {
                            Button(action: { toggleDiff() }) {
                                Image(systemName: showDiff ? "doc.text" : "chevron.left.forwardslash.chevron.right")
                                    .foregroundStyle(showDiff ? .accent : .primary)
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
                            Button(action: { showSource.toggle() }) {
                                Image(systemName: showSource ? "doc.richtext" : "curlybraces")
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
            if case let .gitDiff(_, text) = event, isDiffLoading {
                diffText = text
                isDiffLoading = false
            }
        }
    }

    func toggleDiff() {
        showDiff.toggle()
        if showDiff && diffText == nil {
            isDiffLoading = true
            let workDir = connection.connection(for: environmentId)?.defaultWorkingDirectory ?? path.deletingLastPathComponent
            connection.gitDiff(path: workDir, file: path, environmentId: environmentId)
        }
    }
}
