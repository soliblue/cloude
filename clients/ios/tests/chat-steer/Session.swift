import Foundation
import SwiftData

@Model final class Session {
    var id = UUID()
    var endpoint: Endpoint?
    var providerRaw = "codex"
    var isStreaming = true
    var path: String? = "/fixture"
    var codexThreadId: String? = "native-thread"
    var connectionKey: String {
        "\(id)|\(endpoint?.id.uuidString ?? "")|\(endpoint?.connectionRevision?.uuidString ?? "")|\(path ?? "")"
    }
    var historyScopeKey: String { "\(id)|\(endpoint?.id.uuidString ?? "")|\(path ?? "")|\(codexThreadId ?? "")" }
    var provider: ChatProvider { ChatProvider(rawValue: providerRaw)! }
    init(endpoint: Endpoint) { self.endpoint = endpoint }
}
