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
            return (Int(progress.current), Int(progress.total))
        }
        return nil
    }

    func thumbnailBanner(fullSize: Int64, isLoadingFull: Bool) -> some View {
        Button {
            loadFullQuality(fullSize: fullSize)
        } label: {
            VStack(spacing: DS.Spacing.s) {
                if isLoadingFull {
                    if let progress = currentProgress {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: DS.Size.xxl * 0.8)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.system(size: DS.Text.s))
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .scaleEffect(DS.Scale.m)
                        Text("Loading...")
                            .font(.system(size: DS.Text.s))
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Load Full Quality (\(ByteCountFormatter.string(fromByteCount: fullSize, countStyle: .file)))")
                            .font(.system(size: DS.Text.s))
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Radius.l)
        }
        .disabled(isLoadingFull)
        .padding(.bottom, DS.Spacing.l)
    }

    func loadFullQuality(fullSize: Int64) {
        AppLogger.beginInterval("file.fullQuality", key: path)
        loadPhase = .thumbnail(fullSize: fullSize, isLoadingFull: true)
        connection.getFileFullQuality(path: path, environmentId: environmentId)
    }

    func loadFile() {
        if let cached = connection.fileCache.get(path) {
            AppLogger.performanceInfo("file cache hit path=\(path)")
            fileData = cached
            if contentType.highlightLanguage != nil, let text = String(data: cached, encoding: .utf8) {
                highlightCode(text)
            } else {
                loadPhase = .loaded
            }
            return
        }

        AppLogger.beginInterval("file.load", key: path)
        loadPhase = .loading
        connection.getFile(path: path, environmentId: environmentId)

        let filePath = path
        connection.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .fileChunk(let p, let chunkIndex, let totalChunks, _, _, _):
                    guard p == filePath else { return }
                    withAnimation {
                        chunkProgress = (chunkIndex, totalChunks)
                    }
                case .fileContent(let p, let data, _, _, let truncated):
                    guard p == filePath else { return }
                    AppLogger.endInterval("file.load", key: filePath, details: "kind=content truncated=\(truncated)")
                    AppLogger.endInterval("file.fullQuality", key: filePath, details: "kind=content truncated=\(truncated)")
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                        if contentType.highlightLanguage != nil, let text = String(data: decoded, encoding: .utf8) {
                            highlightCode(text)
                        } else {
                            loadPhase = .loaded
                        }
                    } else {
                        loadPhase = .error("Failed to decode file")
                    }
                case .fileThumbnail(let p, let data, let size):
                    guard p == filePath else { return }
                    AppLogger.endInterval("file.load", key: filePath, details: "kind=thumbnail bytes=\(size)")
                    if let decoded = Data(base64Encoded: data) {
                        fileData = decoded
                        loadPhase = .thumbnail(fullSize: size, isLoadingFull: false)
                    } else {
                        loadPhase = .error("Failed to decode thumbnail")
                    }
                case .directoryListing(let p, let entries, _):
                    guard p == filePath else { return }
                    loadPhase = .directory(entries)
                    AppLogger.endInterval("file.load", key: filePath, details: "kind=directory entries=\(entries.count)")
                case .fileError(let message):
                    loadPhase = .error(message)
                    AppLogger.cancelInterval("file.load", key: filePath, reason: message)
                    AppLogger.cancelInterval("file.fullQuality", key: filePath, reason: message)
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
                    loadPhase = .loaded
                }
            } catch {
                await MainActor.run {
                    loadPhase = .loaded
                }
            }
        }
    }
}
