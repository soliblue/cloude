import Foundation

enum ChatMessageKind: Equatable {
    case user(isQueued: Bool = false)
    case assistant(wasInterrupted: Bool = false)

    var isUser: Bool {
        if case .user = self { return true }
        return false
    }
}
