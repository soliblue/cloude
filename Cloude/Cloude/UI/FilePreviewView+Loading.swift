import SwiftUI
import CloudeShared
import Combine

extension FilePreviewView {
    var currentProgress: (current: Int, total: Int)? {
        if let progress = connection.chunkProgress, progress.path == file.path {
            return (progress.current, progress.total)
        }
        return nil
    }

    @ViewBuilder
    var content: some View {
        if isLoading {
            VStack(spacing: 16) {
                if let progress = currentProgress {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let data = fileData {
            fileContent(data)
        }
    }

    @ViewBuilder
    func fileContent(_ data: Data) -> some View {
        if file.isImage, let image = UIImage(data: data) {
            VStack {
                ImagePreview(image: image)
                if isThumbnail {
                    thumbnailBanner
                }
            }
        } else if file.isVideo {
            VideoPreview(data: data)
        } else if file.isText, let text = String(data: data, encoding: .utf8) {
            TextPreview(text: text)
        } else {
            BinaryPreview(file: file, data: data)
        }
    }

    var thumbnailBanner: some View {
        Button {
            loadFullQuality()
        } label: {
            VStack(spacing: 6) {
                if isLoadingFullQuality {
                    if let progress = currentProgress {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: 160)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Load Full Quality (\(ByteCountFormatter.string(fromByteCount: fullSize, countStyle: .file)))")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .disabled(isLoadingFullQuality)
        .padding(.bottom, 16)
    }

    func loadFullQuality() {
        isLoadingFullQuality = true
        loadProgress = nil
        connection.getFileFullQuality(path: file.path)
    }

    func loadFile() {
        isLoading = true
        loadProgress = nil
        connection.getFile(path: file.path)

        let filePath = file.path
        connection.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .fileChunk(let path, let chunkIndex, let totalChunks, _, _, _):
                    guard path == filePath else { return }
                    withAnimation {
                        loadProgress = (chunkIndex, totalChunks)
                    }
                case .fileContent(let path, let data, _, _, let truncated):
                    guard path == filePath else { return }
                    isLoading = false
                    isLoadingFullQuality = false
                    isTruncated = truncated
                    isThumbnail = false
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                    } else {
                        errorMessage = "Failed to decode file"
                    }
                case .fileThumbnail(let path, let data, let size):
                    guard path == filePath else { return }
                    isLoading = false
                    isThumbnail = true
                    fullSize = size
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                    } else {
                        errorMessage = "Failed to decode thumbnail"
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
