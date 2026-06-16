import Foundation

enum ChatMarkdownInlineSegment: Identifiable, Equatable {
    case text(id: UUID = UUID(), AttributedString)
    case code(id: UUID = UUID(), String)
    case filePath(id: UUID = UUID(), String)
    case lineBreak(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _): return id
        case .filePath(let id, _): return id
        case .lineBreak(let id): return id
        }
    }

    var isSpecial: Bool {
        switch self {
        case .code, .filePath: return true
        case .text, .lineBreak: return false
        }
    }
}
