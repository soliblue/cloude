import Foundation

struct ChatHistoryWindow {
    private(set) var sessionId: UUID?
    private(set) var firstGroupId: UUID?
    let pageSize: Int

    init(pageSize: Int = 50) {
        self.pageSize = max(1, pageSize)
    }

    func startIndex(sessionId: UUID, groupIds: [UUID]) -> Int {
        self.sessionId == sessionId
            ? firstGroupId.flatMap { groupIds.firstIndex(of: $0) } ?? max(0, groupIds.count - pageSize)
            : max(0, groupIds.count - pageSize)
    }

    mutating func synchronize(sessionId: UUID, groupIds: [UUID]) {
        let start = startIndex(sessionId: sessionId, groupIds: groupIds)
        self.sessionId = sessionId
        firstGroupId = groupIds.indices.contains(start) ? groupIds[start] : nil
    }

    mutating func loadEarlier(sessionId: UUID, groupIds: [UUID]) -> UUID? {
        let start = startIndex(sessionId: sessionId, groupIds: groupIds)
        self.sessionId = sessionId
        if start > 0 {
            firstGroupId = groupIds[max(0, start - pageSize)]
        }
        return start > 0 ? groupIds[start] : nil
    }
}
