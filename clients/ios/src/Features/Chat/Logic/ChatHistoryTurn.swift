import Foundation

nonisolated struct ChatHistoryTurn: Sendable {
    let id: String
    let status: String
    let fullPayloadData: Data
}
