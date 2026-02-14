import SwiftUI
import CloudeShared
import Combine
import HighlightSwift

extension FilePreviewView {
    var currentProgress: (current: Int, total: Int)? {
        if let progress = chunkProgress {
            return (progress.current, progress.total)
        }
        if let progress = connection.chunkProgress, progress.path == path {
            return (progress.current, progress.total)
        }
        return nil
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
        connection.getFileFullQuality(path: path)
    }

    func loadFile() {
        if let cached = connection.fileCache.get(path) {
            fileData = cached
            if contentType.highlightLanguage != nil, let text = String(data: cached, encoding: .utf8) {
                highlightCode(text)
            } else {
                isLoading = false
            }
            return
        }

        isLoading = true
        loadProgress = nil
        connection.getFile(path: path)

        let filePath = path
        connection.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .fileChunk(let p, let chunkIndex, let totalChunks, _, _, _):
                    guard p == filePath else { return }
                    withAnimation {
                        chunkProgress = (chunkIndex, totalChunks)
                        loadProgress = (chunkIndex, totalChunks)
                    }
                case .fileContent(let p, let data, _, _, let truncated):
                    guard p == filePath else { return }
                    isLoadingFullQuality = false
                    isTruncated = truncated
                    isThumbnail = false
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                        if contentType.highlightLanguage != nil, let text = String(data: decoded, encoding: .utf8) {
                            highlightCode(text)
                        } else {
                            isLoading = false
                        }
                    } else {
                        errorMessage = "Failed to decode file"
                        isLoading = false
                    }
                case .fileThumbnail(let p, let data, let size):
                    guard p == filePath else { return }
                    isLoading = false
                    isThumbnail = true
                    fullSize = size
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                    } else {
                        errorMessage = "Failed to decode thumbnail"
                    }
                case .directoryListing(let p, let entries):
                    guard p == filePath else { return }
                    directoryEntries = entries
                    isLoading = false
                case .fileError(let message):
                    errorMessage = message
                    isLoading = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    func highlightCode(_ code: String) {
        Task {
            let highlight = Highlight()
            let colors: HighlightColors = colorScheme == .dark ? .dark(.xcode) : .light(.xcode)
            do {
                let result: AttributedString
                if let lang = contentType.highlightLanguage {
                    result = try await highlight.attributedText(code, language: lang, colors: colors)
                } else {
                    result = try await highlight.attributedText(code, colors: colors)
                }
                await MainActor.run {
                    highlightedCode = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
