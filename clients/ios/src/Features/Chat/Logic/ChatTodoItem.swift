import Foundation

struct ChatTodoItem: Equatable {
    enum Status: String { case pending, inProgress = "in_progress", completed }

    let content: String
    let status: Status
}

extension ChatTodoItem {
    static func list(from json: String) -> [ChatTodoItem] {
        let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
        let raw =
            (object?["todos"] as? [[String: Any]]) ?? (object?["items"] as? [[String: Any]]) ?? []
        return raw.map {
            ChatTodoItem(
                content: $0["content"] as? String ?? "",
                status: Status(rawValue: $0["status"] as? String ?? "pending") ?? .pending)
        }
    }
}
