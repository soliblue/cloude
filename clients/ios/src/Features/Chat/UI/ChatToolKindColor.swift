import SwiftUI

extension ChatToolKind {
    var color: Color {
        switch self {
        case .bash: return ThemeColor.success
        case .read: return ThemeColor.blue
        case .write, .edit: return ThemeColor.orange
        case .glob, .grep: return ThemeColor.purple
        case .web: return ThemeColor.cyan
        case .todo: return ThemeColor.yellow
        case .task: return ThemeColor.pink
        case .other: return .secondary
        }
    }
}
