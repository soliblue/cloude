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

    func withId(_ newId: String) -> ChatMarkdownBlock {
        switch self {
        case .text(_, let a, let s): return .text(id: newId, a, segments: s)
        case .code(_, let c, let l, let comp):
            return .code(id: newId, content: c, language: l, isComplete: comp)
        case .table(_, let r): return .table(id: newId, rows: r)
        case .blockquote(_, let c): return .blockquote(id: newId, content: c)
        case .horizontalRule: return .horizontalRule(id: newId)
        case .header(_, let l, let c, let s):
            return .header(id: newId, level: l, content: c, segments: s)
        }
    }

    var contentSignature: String {
        switch self {
        case .text(_, _, let segments):
            return "t:" + Self.firstLineFromSegments(segments)
        case .code(_, let content, let lang, _):
            let head = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
            return "c:\(lang ?? ""):\(head.prefix(48))"
        case .table(_, let rows):
            return "tb:" + (rows.first?.joined(separator: "|") ?? "")
        case .blockquote(_, let content):
            let head = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
            return "q:" + head.prefix(48)
        case .horizontalRule:
            return "hr"
        case .header(_, let level, _, let segments):
            return "h\(level):" + Self.firstLineFromSegments(segments)
        }
    }

    private static func firstLineFromSegments(_ segments: [ChatMarkdownInlineSegment]) -> String {
        var result = ""
        for segment in segments {
            let str: String = {
                switch segment {
                case .text(_, let attr): return String(attr.characters)
                case .code(_, let code): return code
                case .filePath(_, let path): return path
                case .lineBreak: return "\n"
                }
            }()
            if let newlineIndex = str.firstIndex(of: "\n") {
                result += str[..<newlineIndex]
                return String(result.prefix(48))
            }
            result += str
            if result.count >= 48 { return String(result.prefix(48)) }
        }
        return result
    }
}
