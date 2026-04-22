import Foundation

@MainActor
enum ChatLiveStream {
    private static var store: [UUID: ChatLiveSnapshot] = [:]

    static func snapshot(for sessionId: UUID) -> ChatLiveSnapshot {
        if let existing = store[sessionId] { return existing }
        let snap = ChatLiveSnapshot()
        store[sessionId] = snap
        return snap
    }

    static func peek(for sessionId: UUID) -> ChatLiveSnapshot? {
        store[sessionId]
    }

    static func clear(sessionId: UUID) {
        store.removeValue(forKey: sessionId)
    }
}
