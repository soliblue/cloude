import SwiftUI
import CloudeShared
import HighlightSwift

extension FilePreviewView {
    var currentProgress: (current: Int, total: Int)? {
        if let progress = chunkProgress {
            return (progress.current, progress.total)
        }
        if let progress = connection?.files.chunkProgress, progress.path == path {
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
        connection?.files.getFileFullQuality(path: path)
    }

    func loadFile() {
        if let cached = connection?.files.cachedData(for: path) {
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
        connection?.files.getFile(path: path)
    }

    func syncLoadedPath() {
        if let progress = connection?.files.chunkProgress, progress.path == path {
            withAnimation {
                chunkProgress = (Int(progress.current), Int(progress.total))
            }
        }
        if let currentDirectoryListing {
            loadPhase = .directory(currentDirectoryListing)
            chunkProgress = nil
            AppLogger.endInterval("file.load", key: path, details: "kind=directory entries=\(currentDirectoryListing.count)")
            return
        }
        if let currentFileResponse {
            if let cached = connection?.files.cachedData(for: path) {
                fileData = cached
                switch currentFileResponse {
                case .content(_, _, let truncated):
                    chunkProgress = nil
                    AppLogger.endInterval("file.load", key: path, details: "kind=content truncated=\(truncated)")
                    AppLogger.endInterval("file.fullQuality", key: path, details: "kind=content truncated=\(truncated)")
                    if contentType.highlightLanguage != nil, let text = String(data: cached, encoding: .utf8) {
                        highlightCode(text)
                    } else {
                        loadPhase = .loaded
                    }
                case .thumbnail(let fullSize):
                    AppLogger.endInterval("file.load", key: path, details: "kind=thumbnail bytes=\(fullSize)")
                    let isLoadingFull: Bool
                    if case .thumbnail(_, let value) = loadPhase {
                        isLoadingFull = value
                    } else {
                        isLoadingFull = false
                    }
                    loadPhase = .thumbnail(fullSize: fullSize, isLoadingFull: isLoadingFull)
                }
            } else {
                loadPhase = .error("Failed to decode file")
            }
            return
        }
        if let currentPathError {
            chunkProgress = nil
            loadPhase = .error(currentPathError)
            AppLogger.cancelInterval("file.load", key: path, reason: currentPathError)
            AppLogger.cancelInterval("file.fullQuality", key: path, reason: currentPathError)
        }
    }

    func syncDiff() {
        if let currentDiffText, case .loading = diff {
            diff = .loaded(currentDiffText)
        } else if currentDiffError != nil, case .loading = diff {
            diff = .hidden
            diffRequest = nil
        }
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
