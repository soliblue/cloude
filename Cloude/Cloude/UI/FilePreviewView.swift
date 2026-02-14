import SwiftUI
import CloudeShared
import Combine
import HighlightSwift

struct FilePreviewView: View {
    let path: String
    @ObservedObject var connection: ConnectionManager
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
    @State var chunkProgress: (current: Int, total: Int)?

    init(file: FileEntry, connection: ConnectionManager, onBrowseFolder: ((String) -> Void)? = nil) {
        self.path = file.path
        self.fileEntry = file
        self.connection = connection
        self.onBrowseFolder = onBrowseFolder
    }

    init(path: String, connection: ConnectionManager) {
        self.path = path
        self.fileEntry = nil
        self.connection = connection
    }

    var fileName: String { path.lastPathComponent }
    var fileExtension: String { path.pathExtension.lowercased() }
    var contentType: FileContentType { .from(extension: fileExtension) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let folder = browsingFolder {
                    FileBrowserView(connection: connection, rootPath: folder)
                } else {
                    FileViewerBreadcrumb(path: path) { folderPath in
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
                            .padding(12)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FileViewerActions(
                        path: path,
                        fileData: fileData,
                        isCodeFile: contentType.isTextBased,
                        onGitDiff: contentType.isTextBased ? { loadGitDiff() } : nil
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if contentType.hasRenderedView && fileData != nil {
                            Button(action: { showSource.toggle() }) {
                                Image(systemName: showSource ? "doc.richtext" : "curlybraces")
                            }
                            Divider()
                                .frame(height: 20)
                        }
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                    .padding(.horizontal, 12)
                    .font(.body)
                }
            }
            .sheet(isPresented: $showDiff) {
                FileDiffSheet(
                    fileName: fileName,
                    diff: diffText,
                    isLoading: isDiffLoading
                )
            }
        }
        .onAppear { loadFile() }
        .onReceive(connection.events) { event in
            if case let .gitDiff(gitPath, text) = event {
                if gitPath == path || gitPath.hasSuffix("/" + path) {
                    diffText = text
                    isDiffLoading = false
                }
            }
        }
    }

    func loadGitDiff() {
        isDiffLoading = true
        diffText = nil
        showDiff = true
        connection.gitDiff(path: path.deletingLastPathComponent, file: path)
    }
}
