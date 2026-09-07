import Foundation
import SwiftData

@Model final class Session {
    var id = UUID()
    var endpoint: Endpoint?
    var providerRaw = "codex"
    var isStreaming = true
    var provider: ChatProvider { ChatProvider(rawValue: providerRaw)! }
    init(endpoint: Endpoint) { self.endpoint = endpoint }
}
