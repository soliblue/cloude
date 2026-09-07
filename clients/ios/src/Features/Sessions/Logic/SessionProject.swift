import Foundation

nonisolated struct SessionProject: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let roots: [SessionProjectRoot]
    var displayName: String { name.isEmpty ? "Untitled project" : name }
    var selectableRoots: [SessionProjectRoot] {
        var seen: Set<String> = []
        return roots.filter { !id.isEmpty && $0.isAbsolute && seen.insert($0.path).inserted }
    }
}
