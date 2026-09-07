import Foundation
import Observation

@MainActor @Observable final class SessionMcpStore {
    var servers: [SessionMcpServer] = []
    var nextCursor: String?
    var isLoading = false
    var error: String?
    var generation = UUID()
}
