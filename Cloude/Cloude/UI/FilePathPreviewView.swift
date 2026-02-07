import SwiftUI
import CloudeShared
import HighlightSwift

struct FilePathPreviewView: View {
    let path: String
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State var isLoading = true
    @State var fileData: Data?
    @State var mimeType: String?
    @State var errorMessage: String?
    @State var highlightedCode: AttributedString?
    @State var directoryEntries: [FileEntry]?
    @State var browsingFolder: String?
    @State var showDiff = false
    @State var diffText: String?
    @State var isDiffLoading = false
    @State var showSource = false

    var fileName: String {
        path.lastPathComponent
    }

    var fileExtension: String {
        path.pathExtension.lowercased()
    }

    var contentType: FileContentType {
        .from(extension: fileExtension)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let folder = browsingFolder {
                    FileBrowserView(connection: connection, rootPath: folder)
                } else {
                    FileViewerBreadcrumb(path: path) { folderPath in
                        browsingFolder = folderPath
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
    }

    func loadGitDiff() {
        isDiffLoading = true
        diffText = nil
        showDiff = true

        let dir = path.deletingLastPathComponent
        connection.onGitDiff = { _, text in
            diffText = text
            isDiffLoading = false
        }
        connection.gitDiff(path: dir, file: path)
    }
}
