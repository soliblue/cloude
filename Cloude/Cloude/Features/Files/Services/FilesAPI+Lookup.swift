import Foundation
import CloudeShared

extension FilesAPI {
    func directoryListing(for path: String) -> [FileEntry]? {
        directoryListings[path]
    }

    func fileResponse(for path: String) -> LoadedFileState? {
        fileResponses[path]
    }

    func pathError(for path: String) -> String? {
        pathErrors[path]
    }

    func cachedData(for path: String) -> Data? {
        fileCache.get(path)
    }
}
