import Foundation

@MainActor
enum ChatLiveTasks {
    private static var store: [UUID: ChatTaskSnapshot] = [:]

    static func snapshot(for sessionId: UUID) -> ChatTaskSnapshot {
        if let existing = store[sessionId] { return existing }
        let snap = ChatTaskSnapshot()
        store[sessionId] = snap
        return snap
    }

    static func clear(sessionId: UUID) {
        store.removeValue(forKey: sessionId)
    }
}
