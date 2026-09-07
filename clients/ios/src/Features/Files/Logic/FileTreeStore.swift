import Foundation
import Observation

@Observable
final class FileTreeStore {
    var children: [String: [FileNodeDTO]] = [:]
    var expanded: Set<String> = []
    var loading: Set<String> = []
    var failed: Set<String> = []
    var rootPath = ""
    var rows: [FileTreeEntry] = []
}
