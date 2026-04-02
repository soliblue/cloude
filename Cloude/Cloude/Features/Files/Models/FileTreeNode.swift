import Foundation
import CloudeShared

struct FileTreeNode: Identifiable {
    var id: String { entry.path }
    let entry: FileEntry
    let depth: Int
    let isExpanded: Bool
    let isLoading: Bool
}
