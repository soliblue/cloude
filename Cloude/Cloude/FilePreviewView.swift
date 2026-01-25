import SwiftUI
import AVKit

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
                        Button("Done") { dismiss() }
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

struct ImagePreview: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width * scale)
                    .scaleEffect(scale)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale = $0 }
                .onEnded { _ in scale = max(1.0, min(scale, 5.0)) }
        )
    }
}

struct VideoPreview: View {
    let data: Data

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try? data.write(to: tempURL)
        player = AVPlayer(url: tempURL)
    }
}

struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BinaryPreview: View {
    let file: FileEntry
    let data: Data

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: file.icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(file.name)
                .font(.headline)

            Text(file.formattedSize)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Binary file - cannot preview")
                .font(.caption)
                .foregroundColor(.secondary)

            ShareLink(item: data, preview: SharePreview(file.name)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
