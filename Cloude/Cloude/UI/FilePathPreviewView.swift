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

    var fileName: String {
        path.lastPathComponent
    }

    var fileExtension: String {
        path.pathExtension.lowercased()
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
                        isCodeFile: isText,
                        onGitDiff: isText ? { loadGitDiff() } : nil
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
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
