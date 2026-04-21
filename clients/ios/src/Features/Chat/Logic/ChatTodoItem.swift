import Foundation

struct ChatTodoItem: Equatable {
    enum Status: String { case pending, inProgress = "in_progress", completed }

    let content: String
    let status: Status
}
