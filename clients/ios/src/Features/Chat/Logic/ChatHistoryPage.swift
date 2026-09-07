import Foundation

nonisolated struct ChatHistoryPage: Sendable {
    let threadId: String
    let turns: [ChatHistoryTurn]
    let nextCursor: String?
    let backwardsCursor: String?

    @concurrent
    static func decode(_ data: Data) async -> ChatHistoryPage? {
        if !Task.isCancelled,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let threadId = object["threadId"] as? String, validIdentity(threadId),
            let turns = object["data"] as? [[String: Any]], turns.count <= 50,
            validCursor(object["nextCursor"]), validCursor(object["backwardsCursor"])
        {
            var result: [ChatHistoryTurn] = []
            var turnIds: Set<String> = []
            var itemIds: Set<String> = []
            for turn in turns {
                if Task.isCancelled { return nil }
                guard let id = turn["id"] as? String, validIdentity(id), turnIds.insert(id).inserted,
                    let status = turn["status"] as? String,
                    ["completed", "interrupted", "failed", "inProgress"].contains(status),
                    turn["itemsView"] == nil || turn["itemsView"] as? String == "full",
                    let items = turn["items"] as? [[String: Any]]
                else { return nil }
                for item in items {
                    guard let id = item["id"] as? String, validIdentity(id), itemIds.insert(id).inserted,
                        let type = item["type"] as? String, validIdentity(type)
                    else { return nil }
                }
                guard let payload = try? JSONSerialization.data(withJSONObject: turn) else { return nil }
                result.append(ChatHistoryTurn(id: id, status: status, fullPayloadData: payload))
            }
            return ChatHistoryPage(
                threadId: threadId, turns: result, nextCursor: object["nextCursor"] as? String,
                backwardsCursor: object["backwardsCursor"] as? String)
        }
        return nil
    }

    static func validIdentity(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf16.count <= 512
            && !value.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
    }

    private static func validCursor(_ value: Any?) -> Bool {
        value == nil || value is NSNull
            || (value as? String).map {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf16.count <= 4096
                    && !$0.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
            } == true
    }
}
