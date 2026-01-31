import SwiftUI
import AVKit
import CloudeShared

struct FilePreviewView: View {
    let file: FileEntry
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = true
    @State private var fileData: Data?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(file.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
        .onAppear { loadFile() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading...")
        } else if let error = errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let data = fileData {
            fileContent(data)
        }
    }

    @ViewBuilder
    private func fileContent(_ data: Data) -> some View {
        if file.isImage, let image = UIImage(data: data) {
            ImagePreview(image: image)
        } else if file.isVideo {
            VideoPreview(data: data)
        } else if file.isText, let text = String(data: data, encoding: .utf8) {
            TextPreview(text: text)
        } else {
            BinaryPreview(file: file, data: data)
        }
    }

    private func loadFile() {
        isLoading = true
        connection.getFile(path: file.path)

        connection.onFileContent = { path, data, mimeType, size in
            guard path == file.path else { return }
            isLoading = false

            if let decoded = Data(base64Encoded: data) {
                fileData = decoded
            } else {
                errorMessage = "Failed to decode file"
            }
        }
    }
}
