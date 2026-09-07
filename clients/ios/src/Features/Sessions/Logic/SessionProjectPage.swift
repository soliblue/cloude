import Foundation

nonisolated struct SessionProjectPage: Codable, Sendable {
    let data: [SessionProject]
    let nextCursor: String?
}
