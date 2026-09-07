import Foundation

nonisolated struct SessionWorktreeResult: Codable {
    let path: String
    let branch: String
    let head: String
}
