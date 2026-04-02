import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleFileContent(_ mgr: ConnectionManager, path: String, data: String, mimeType: String, size: Int64, truncated: Bool) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        mgr.events.send(.fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated))
    }

    func handleFileChunk(_ mgr: ConnectionManager, path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64) {
        chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
        mgr.events.send(.fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size))
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
            pendingChunks.removeValue(forKey: path)
            mgr.events.send(.fileContent(path: path, data: combinedData.base64EncodedString(), mimeType: pending.mimeType, size: pending.size, truncated: false))
        }
    }

    func handleGitStatusResult(_ mgr: ConnectionManager, _ status: GitStatusInfo) {
        gitStatusTimeoutTask?.cancel()
        let path = gitStatusInFlightPath ?? ""
        gitStatusInFlightPath = nil
        mgr.events.send(.gitStatus(path: path, status: status, environmentId: environmentId))
        sendNextGitStatusIfNeeded()
    }

}
