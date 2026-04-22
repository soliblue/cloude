import Foundation

enum ChatMarkdownBlock: Identifiable {
    case text(id: String, AttributedString, segments: [ChatMarkdownInlineSegment])
    case code(id: String, content: String, language: String?, isComplete: Bool)
    case table(id: String, rows: [[String]])
    case blockquote(id: String, content: String)
    case horizontalRule(id: String)
    case header(id: String, level: Int, content: AttributedString, segments: [ChatMarkdownInlineSegment])

    var id: String {
        switch self {
        case .text(let id, _, _): return id
        case .code(let id, _, _, _): return id
        case .table(let id, _): return id
        case .blockquote(let id, _): return id
        case .horizontalRule(let id): return id
        case .header(let id, _, _, _): return id
        }
    }

    func prefixed(_ prefix: String) -> ChatMarkdownBlock {
        switch self {
        case .text(let id, let a, let s): return .text(id: prefix + id, a, segments: s)
        case .code(let id, let c, let l, let comp):
            return .code(id: prefix + id, content: c, language: l, isComplete: comp)
        case .table(let id, let r): return .table(id: prefix + id, rows: r)
        case .blockquote(let id, let c): return .blockquote(id: prefix + id, content: c)
        case .horizontalRule(let id): return .horizontalRule(id: prefix + id)
        case .header(let id, let l, let c, let s):
            return .header(id: prefix + id, level: l, content: c, segments: s)
        }
    }
}
