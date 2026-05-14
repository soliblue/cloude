import Foundation

@Observable
final class FileTreeStore {
    var children: [String: [FileNodeDTO]] = [:]
    var expanded: Set<String> = []
    var loading: Set<String> = []
    var rootPath: String = ""
}
