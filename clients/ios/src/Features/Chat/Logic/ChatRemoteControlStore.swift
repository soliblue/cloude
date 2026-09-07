import Foundation
import Observation

@MainActor @Observable final class ChatRemoteControlStore {
    static let shared = ChatRemoteControlStore()
    var submitting: Set<UUID> = []
    var requested: Set<UUID> = []
    var errors: [UUID: String] = [:]

    func clear(sessionId: UUID) {
        submitting.remove(sessionId)
        requested.remove(sessionId)
        errors.removeValue(forKey: sessionId)
    }
}
