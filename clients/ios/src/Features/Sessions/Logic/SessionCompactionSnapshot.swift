import Foundation

nonisolated struct SessionCompactionSnapshot: Decodable {
    let status: String
    let threadId: String?
    let error: String?
    let contextTokens: Int?
    let contextWindow: Int?
}
