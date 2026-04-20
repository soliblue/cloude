import Foundation

enum SessionTab: String, CaseIterable, Identifiable, Codable {
    case chat, files, git

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat: return "Chat"
        case .files: return "Files"
        case .git: return "Git"
        }
    }

    var symbol: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .files: return "folder.fill"
        case .git: return "arrow.triangle.branch"
        }
    }
}
