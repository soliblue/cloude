import Foundation
import SwiftData

@Model final class Session {
    @Attribute(.unique) var id = UUID()
    var endpoint: Endpoint?
    var totalCostUsd: Double = 0
    var modelRaw: String?
    var followsRemote = true
    var isStreaming = false
    var remoteIsRunning = false
    var remoteTurnStatus: String?
    var title = "Untitled Codex chat"
    var hasCustomTitle = false
    var path: String?
    var connectionKey: String {
        "\(id)|\(endpoint?.id.uuidString ?? "")|\(endpoint?.connectionRevision?.uuidString ?? "")|\(path ?? "")"
    }
    var lastSeq = -1
    var remoteHistoryETag: String?
    var existsOnServer = true
    var providerRaw = "codex"
    var goalData: Data?
    var provider: ChatProvider { ChatProvider(rawValue: providerRaw) ?? .claude }
    var goal: ChatGoal? { goalData.flatMap { try? JSONDecoder().decode(ChatGoal.self, from: $0) } }
    init(endpoint: Endpoint) { self.endpoint = endpoint }
}
