import Foundation

@MainActor
enum ChatGoalRequestStore {
    private static var requests: [UUID: UUID] = [:]
    private static var mutations: Set<UUID> = []

    static func begin(sessionId: UUID, mutating: Bool) -> UUID? {
        if mutating || !mutations.contains(sessionId) {
            let id = UUID()
            requests[sessionId] = id
            if mutating { mutations.insert(sessionId) }
            return id
        }
        return nil
    }

    static func finish(_ requestId: UUID, sessionId: UUID) -> Bool {
        if requests[sessionId] == requestId {
            cancel(sessionId: sessionId)
            return true
        }
        return false
    }

    static func cancel(sessionId: UUID) {
        requests.removeValue(forKey: sessionId)
        mutations.remove(sessionId)
    }
}
