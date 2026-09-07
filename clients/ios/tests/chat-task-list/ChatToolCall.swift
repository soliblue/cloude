import Foundation

struct ChatToolCall {
    let name: String
    let order: Int
    var parsedInput: [String: Any] = [:]
    var result: String? = nil
    var todoItems: [ChatTodoItem]? = nil
}
