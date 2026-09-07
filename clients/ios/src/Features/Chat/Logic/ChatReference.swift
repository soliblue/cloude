import Foundation

nonisolated struct ChatReference: Codable, Equatable {
    let name: String
    let path: String
    let kind: String
}
