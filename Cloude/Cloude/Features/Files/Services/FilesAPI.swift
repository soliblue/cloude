import Foundation
import Combine
import CloudeShared

@MainActor
final class FilesAPI: ObservableObject {
    let environmentId: UUID

    @Published private(set) var directoryListings: [String: [FileEntry]] = [:]
    @Published private(set) var fileResponses: [String: LoadedFileState] = [:]
    @Published private(set) var pathErrors: [String: String] = [:]
    @Published private(set) var searchResults: [String] = []
    @Published private(set) var searchError: String?
    @Published private(set) var chunkProgress: ChunkProgress?

    var send: ((ClientMessage) -> Void)?
    var fileCache = FileCache()
    var pendingChunks: [String: PendingChunk] = [:]
    var pendingPathRequests: Set<String> = []
    var hasPendingSearch = false

    init(environmentId: UUID) {
        self.environmentId = environmentId
    }

    func clearSearch() {
        searchResults = []
        searchError = nil
        hasPendingSearch = false
    }

    func search(query: String, workingDirectory: String) {
        searchResults = []
        searchError = nil
        hasPendingSearch = true
        AppLogger.connectionInfo("file search request envId=\(environmentId.uuidString) workingDirectory=\(workingDirectory) query=\(query)")
        send?(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func listDirectory(path: String) {
        pendingPathRequests.insert(path)
        pathErrors.removeValue(forKey: path)
        AppLogger.connectionInfo("directory request envId=\(environmentId.uuidString) path=\(path)")
        send?(.listDirectory(path: path))
    }

    func getFile(path: String) {
        requestFile(path: path, fullQuality: false)
    }

    func getFileFullQuality(path: String) {
        requestFile(path: path, fullQuality: true)
    }

    func handleDirectoryListing(path: String, entries: [FileEntry]) {
        pendingPathRequests.remove(path)
        pathErrors.removeValue(forKey: path)
        fileResponses.removeValue(forKey: path)
        directoryListings[path] = entries
        AppLogger.connectionInfo("directory response envId=\(environmentId.uuidString) path=\(path) entries=\(entries.count)")
    }

    func handleFileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        pendingPathRequests.remove(path)
        pendingChunks.removeValue(forKey: path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        directoryListings.removeValue(forKey: path)
        fileResponses[path] = .content(mimeType: mimeType, size: size, truncated: truncated)
        AppLogger.connectionInfo("file response envId=\(environmentId.uuidString) path=\(path) kind=content bytes=\(size) truncated=\(truncated) mimeType=\(mimeType)")
    }

    func handleFileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64) {
        chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
        if pendingChunks[path] == nil {
            pendingChunks[path] = PendingChunk(chunks: [:], totalChunks: totalChunks, mimeType: mimeType, size: size)
        }
        pendingChunks[path]?.chunks[chunkIndex] = data
        if let pending = pendingChunks[path], (0..<pending.totalChunks).allSatisfy({ pending.chunks[$0] != nil }) {
            var combinedData = Data()
            for index in 0..<pending.totalChunks {
                if let chunkBase64 = pending.chunks[index], let chunkData = Data(base64Encoded: chunkBase64) {
                    combinedData.append(chunkData)
                }
            }
            handleFileContent(path: path, data: combinedData.base64EncodedString(), mimeType: pending.mimeType, size: pending.size, truncated: false)
        }
    }

    func handleFileThumbnail(path: String, data: String, fullSize: Int64) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        pendingPathRequests.remove(path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        directoryListings.removeValue(forKey: path)
        fileResponses[path] = .thumbnail(fullSize: fullSize)
        AppLogger.connectionInfo("file response envId=\(environmentId.uuidString) path=\(path) kind=thumbnail bytes=\(fullSize)")
    }

    func handleSearchResults(_ files: [String]) {
        hasPendingSearch = false
        searchError = nil
        searchResults = files
        AppLogger.connectionInfo("file search response envId=\(environmentId.uuidString) count=\(files.count)")
    }

    func reset() {
        chunkProgress = nil
        directoryListings = [:]
        fileResponses = [:]
        pathErrors = [:]
        searchResults = []
        searchError = nil
        pendingPathRequests = []
        pendingChunks = [:]
        hasPendingSearch = false
    }

    func failPendingOperations(_ message: String) {
        for path in pendingPathRequests {
            pathErrors[path] = message
        }
        if hasPendingSearch {
            searchError = message
            searchResults = []
        }
        pendingPathRequests = []
        pendingChunks = [:]
        hasPendingSearch = false
        chunkProgress = nil
    }

    private func requestFile(path: String, fullQuality: Bool) {
        pendingPathRequests.insert(path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        AppLogger.connectionInfo("file request envId=\(environmentId.uuidString) path=\(path) quality=\(fullQuality ? "full" : "default")")
        send?(fullQuality ? .getFileFullQuality(path: path) : .getFile(path: path))
    }
}
