import Foundation

@Observable
final class FileTreeStore {
    var children: [String: [FileNodeDTO]] = [:]
    var expanded: Set<String> = []
    var loading: Set<String> = []
    var previewNode: FileNodeDTO?
    var rootPath: String = ""
}
