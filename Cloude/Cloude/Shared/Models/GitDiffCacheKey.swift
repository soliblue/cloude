import Foundation

struct GitDiffCacheKey: Hashable {
    let repoPath: String
    let filePath: String?
    let staged: Bool
}
