import Foundation

let taskCount = 20_000
let creates = (0..<taskCount).map {
    ChatToolCall(name: "TaskCreate", order: $0, parsedInput: ["subject": "Task \($0)"])
}
let updates = (0..<taskCount).map {
    ChatToolCall(name: "TaskUpdate", order: taskCount + $0, parsedInput: ["taskId": $0 + 1, "status": "completed"])
}
let calls = creates + updates
let before = Date()
let legacy = ChatTaskListLegacy.items(from: calls)
let legacyTime = Date().timeIntervalSince(before)
let after = Date()
let optimized = ChatTaskList.items(from: calls)
let optimizedTime = Date().timeIntervalSince(after)
precondition(legacy == optimized && optimized.count == taskCount && optimized.allSatisfy { $0.status == .completed })
print(
    "20,000 tasks + 20,000 updates: legacy \(String(format: "%.2f", legacyTime * 1000))ms; indexed \(String(format: "%.2f", optimizedTime * 1000))ms"
)
var mixed: [ChatToolCall] = []
var seed: UInt64 = 923457
for index in 0..<1000 {
    seed = seed &* 6_364_136_223_846_793_005 &+ 1
    let id = Int(seed % 30)
    switch seed % 7 {
    case 0:
        mixed.append(
            ChatToolCall(
                name: "TodoWrite", order: index,
                todoItems: [
                    ChatTodoItem(content: "Plan", status: .inProgress), ChatTodoItem(content: "Next", status: .pending),
                ]))
    case 1:
        mixed.append(ChatToolCall(name: "TaskUpdate", order: index, parsedInput: ["taskId": id, "status": "deleted"]))
    case 2:
        mixed.append(
            ChatToolCall(
                name: "TaskCreate", order: index, parsedInput: ["subject": "Explicit \(id)"],
                result: "Task #\(id) created"))
    case 3:
        mixed.append(
            ChatToolCall(
                name: "TaskUpdate", order: index,
                parsedInput: ["taskId": String(id), "status": "completed", "subject": "Updated \(index)"]))
    case 4:
        mixed.append(ChatToolCall(name: "update_plan", order: index, todoItems: []))
    default:
        mixed.append(ChatToolCall(name: "TaskCreate", order: index, parsedInput: ["subject": "Generated \(index)"]))
    }
    if index.isMultiple(of: 23) {
        precondition(ChatTaskList.items(from: mixed) == ChatTaskListLegacy.items(from: mixed))
    }
}
precondition(ChatTaskList.items(from: mixed.reversed()) == ChatTaskListLegacy.items(from: mixed))
let deletedMax = [
    ChatToolCall(name: "TaskCreate", order: 0, result: "#3"),
    ChatToolCall(name: "TaskUpdate", order: 1, parsedInput: ["taskId": 3, "status": "deleted"]),
    ChatToolCall(name: "TaskCreate", order: 2, parsedInput: ["subject": "Reused"]),
    ChatToolCall(name: "TaskUpdate", order: 3, parsedInput: ["taskId": 1, "status": "completed"]),
]
precondition(ChatTaskList.items(from: deletedMax) == [ChatTodoItem(content: "Reused", status: .completed)])
precondition(ChatTaskList.items(from: calls) == optimized)
precondition(ChatTaskList.items(from: []) == [])
print(
    "Passed exact task order/status parity, resets, unknown/duplicate IDs, deletion/recreation, fallback numbering and independent input lists"
)
