import Foundation
import CloudeShared

struct GitDiffRequest: Identifiable {
    let id = UUID()
    let repoPath: String
    let file: GitFileStatus
    let environmentId: UUID?
}
