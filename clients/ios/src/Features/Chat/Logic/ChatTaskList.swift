import Foundation

enum ChatTaskList {
    static func items(from calls: [ChatToolCall]) -> [ChatTodoItem] {
        var tasks: [(id: Int, content: String, status: ChatTodoItem.Status)] = []
        for call in calls.sorted(by: { $0.order < $1.order }) {
            let input = call.parsedInput
            switch call.name {
            case "TaskCreate":
                let id =
                    call.result.flatMap { $0.firstMatch(of: #/#(\d+)/#) }.flatMap { Int($0.1) }
                    ?? (tasks.map(\.id).max() ?? 0) + 1
                if !tasks.contains(where: { $0.id == id }) {
                    tasks.append((id, input["subject"] as? String ?? "", .pending))
                }
            case "TaskUpdate":
                let taskId =
                    input["taskId"] as? String ?? (input["taskId"] as? Int).map { String($0) }
                if let taskId, let id = Int(taskId),
                    let index = tasks.firstIndex(where: { $0.id == id })
                {
                    if let subject = input["subject"] as? String { tasks[index].content = subject }
                    if let status = input["status"] as? String {
                        if status == "deleted" {
                            tasks.remove(at: index)
                        } else if let parsed = ChatTodoItem.Status(rawValue: status) {
                            tasks[index].status = parsed
                        }
                    }
                }
            default: break
            }
        }
        return tasks.map { ChatTodoItem(content: $0.content, status: $0.status) }
    }
}
