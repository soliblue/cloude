import Foundation

struct FileTreeEntry: Identifiable {
    let node: FileNodeDTO
    let depth: Int
    var id: String { node.path }
}
