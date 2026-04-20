import Foundation
import CloudeShared

extension GitAPI {
    func statusInfo(for path: String) -> GitStatusInfo? {
        statuses[path]
    }

    func statusError(for path: String) -> String? {
        statusErrors[path]
    }

    func logEntries(for path: String) -> [GitCommit]? {
        logs[path]
    }

    func logError(for path: String) -> String? {
        logErrors[path]
    }

    func diffText(repoPath: String, file: String? = nil, staged: Bool = false) -> String? {
        diffs[GitDiffCacheKey(repoPath: repoPath, filePath: file, staged: staged)]
    }

    func diffError(repoPath: String, file: String? = nil, staged: Bool = false) -> String? {
        diffErrors[GitDiffCacheKey(repoPath: repoPath, filePath: file, staged: staged)]
    }
}
