import Foundation

enum ChatTaskList {
    static func items(from calls: [ChatToolCall]) -> [ChatTodoItem] {
        var tasks: [Int: (position: Int, content: String, status: ChatTodoItem.Status)] = [:]
        var order: [Int?] = []
        var maximumId: Int? = 0
        for call in calls.sorted(by: { $0.order < $1.order }) {
            let input = call.parsedInput
            switch call.name {
            case "TodoWrite", "update_plan":
                tasks.removeAll(keepingCapacity: true)
                order.removeAll(keepingCapacity: true)
                for (index, item) in (call.todoItems ?? []).enumerated() {
                    tasks[index] = (index, item.content, item.status)
                    order.append(index)
                }
                maximumId = order.last.flatMap { $0 } ?? 0
            case "TaskCreate":
                if maximumId == nil { maximumId = tasks.keys.max() ?? 0 }
                let id =
                    call.result.flatMap { $0.firstMatch(of: #/#(\d+)/#) }.flatMap { Int($0.1) }
                    ?? (maximumId ?? 0) + 1
                if tasks[id] == nil {
                    tasks[id] = (order.count, input["subject"] as? String ?? "", .pending)
                    order.append(id)
                    maximumId = max(maximumId ?? 0, id)
                }
            case "TaskUpdate":
                let taskId = input["taskId"] as? String ?? (input["taskId"] as? Int).map(String.init)
                if let taskId, let id = Int(taskId), var task = tasks[id] {
                    if let subject = input["subject"] as? String { task.content = subject }
                    if let status = input["status"] as? String, let parsed = ChatTodoItem.Status(rawValue: status) {
                        task.status = parsed
                    }
                    if input["status"] as? String == "deleted" {
                        tasks.removeValue(forKey: id)
                        order[task.position] = nil
                        if maximumId == id { maximumId = nil }
                    } else {
                        tasks[id] = task
                    }
                }
            default: break
            }
        }
        return order.compactMap { id in
            id.flatMap { tasks[$0] }.map { ChatTodoItem(content: $0.content, status: $0.status) }
        }
    }
}
