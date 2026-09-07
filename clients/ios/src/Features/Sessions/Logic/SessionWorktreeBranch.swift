import Foundation

nonisolated struct SessionWorktreeBranch: Codable, Identifiable, Equatable {
    let name: String
    let current: Bool
    var id: String { name }
}
