import SwiftUI
import CloudeShared
import Combine

struct FilePreviewView: View {
    let file: FileEntry
    @ObservedObject var connection: ConnectionManager
    var onBrowseFolder: ((String) -> Void)?
    @Environment(\.dismiss) var dismiss

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FileViewerBreadcrumb(path: file.path) { folderPath in
                    dismiss()
                    onBrowseFolder?(folderPath)
                }
                Divider()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FileViewerActions(
                        path: file.path,
                        fileData: fileData,
                        isCodeFile: file.isText,
                        onGitDiff: file.isText ? { loadGitDiff() } : nil
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
                    fileName: file.name,
                    diff: diffText,
                    isLoading: isDiffLoading
                )
            }
        }
        .onAppear { loadFile() }
    }

    private func loadGitDiff() {
        isDiffLoading = true
        diffText = nil
        showDiff = true

        let dir = file.path.deletingLastPathComponent
        connection.onGitDiff = { _, text in
            diffText = text
            isDiffLoading = false
        }
        connection.gitDiff(path: dir, file: file.path)
    }
}
