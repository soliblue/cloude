import Foundation

@main
struct Main {
    @MainActor
    static func main() {
        let session = UUID()
        let ids = (0..<1000).map { _ in UUID() }
        var window = ChatHistoryWindow()
        precondition(window.startIndex(sessionId: session, groupIds: ids) == 950)
        window.synchronize(sessionId: session, groupIds: ids)
        precondition(window.firstGroupId == ids[950])

        let appended = ids + [UUID(), UUID()]
        window.synchronize(sessionId: session, groupIds: appended)
        precondition(window.startIndex(sessionId: session, groupIds: appended) == 950)
        precondition(appended.count - window.startIndex(sessionId: session, groupIds: appended) == 52)
        precondition(window.loadEarlier(sessionId: session, groupIds: appended) == ids[950])
        precondition(window.firstGroupId == ids[900])

        let prepended = [UUID(), UUID(), UUID()] + appended
        window.synchronize(sessionId: session, groupIds: prepended)
        precondition(window.startIndex(sessionId: session, groupIds: prepended) == 903)
        precondition(window.firstGroupId == ids[900])
        var anchors = Set<UUID>()
        while let anchor = window.loadEarlier(sessionId: session, groupIds: prepended) {
            precondition(anchors.insert(anchor).inserted)
        }
        precondition(window.startIndex(sessionId: session, groupIds: prepended) == 0)
        precondition(window.firstGroupId == prepended.first)
        precondition(window.loadEarlier(sessionId: session, groupIds: prepended) == nil)

        let otherSession = UUID()
        precondition(window.startIndex(sessionId: otherSession, groupIds: ids) == 950)
        window.synchronize(sessionId: otherSession, groupIds: ids)
        precondition(window.firstGroupId == ids[950])
        let short = Array(ids.suffix(10))
        window.synchronize(sessionId: otherSession, groupIds: short)
        precondition(window.startIndex(sessionId: otherSession, groupIds: short) == 0)
        precondition(window.loadEarlier(sessionId: otherSession, groupIds: short) == nil)

        var empty = ChatHistoryWindow()
        empty.synchronize(sessionId: session, groupIds: [])
        precondition(empty.firstGroupId == nil)
        precondition(empty.loadEarlier(sessionId: session, groupIds: []) == nil)
        empty.synchronize(sessionId: session, groupIds: ids)
        precondition(empty.firstGroupId == ids[950])
        precondition(ChatHistoryWindow(pageSize: 0).startIndex(sessionId: session, groupIds: ids) == 999)
        print(
            "Chat history window tests passed: bounded initial history, stable append/prepend boundary, complete pagination, session reset, empty hydration"
        )
    }
}
