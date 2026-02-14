import Foundation
import Combine
import CloudeShared

extension ConnectionManager {
    func handleDirectoryListing(path: String, entries: [FileEntry]) {
        events.send(.directoryListing(path: path, entries: entries))
    }

    func handleFileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        events.send(.fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated))
    }

    func handleFileThumbnail(path: String, data: String, fullSize: Int64) {
        events.send(.fileThumbnail(path: path, data: data, fullSize: fullSize))
    }

    func handleFileSearchResults(files: [String], query: String) {
        events.send(.fileSearchResults(files: files, query: query))
    }

    func handleGitStatusResult(_ status: GitStatusInfo) {
        let path = gitStatusInFlightPath ?? ""
        gitStatusInFlightPath = nil
        events.send(.gitStatus(path: path, status: status))
        sendNextGitStatusIfNeeded()
    }

    func handleGitDiffResult(path: String, diff: String) {
        events.send(.gitDiff(path: path, diff: diff))
    }

    func handleFileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64) {
        chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
        events.send(.fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size))
        if pendingChunks[path] == nil {
            pendingChunks[path] = (chunks: [:], totalChunks: totalChunks, mimeType: mimeType, size: size)
        }
        pendingChunks[path]?.chunks[chunkIndex] = data
        if let pending = pendingChunks[path], (0..<pending.totalChunks).allSatisfy({ pending.chunks[$0] != nil }) {
            var combinedData = Data()
            for i in 0..<pending.totalChunks {
                if let chunkBase64 = pending.chunks[i], let chunkData = Data(base64Encoded: chunkBase64) {
                    combinedData.append(chunkData)
                }
            }
            let combinedBase64 = combinedData.base64EncodedString()
            pendingChunks.removeValue(forKey: path)
            events.send(.fileContent(path: path, data: combinedBase64, mimeType: pending.mimeType, size: pending.size, truncated: false))
        }
    }
}
