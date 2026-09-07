import Foundation

nonisolated struct ChatAgentAttention: Identifiable, Equatable {
    let threadId: String
    let requestId: String
    var id: String { requestId }
}
