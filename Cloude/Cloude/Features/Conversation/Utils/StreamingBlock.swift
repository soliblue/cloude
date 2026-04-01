import Foundation

enum StreamingBlock: Identifiable {
    case text(id: String, AttributedString, segments: [InlineSegment])
    case code(id: String, content: String, language: String?, isComplete: Bool)
    case table(id: String, rows: [[String]])
    case blockquote(id: String, content: String)
    case horizontalRule(id: String)
    case header(id: String, level: Int, content: AttributedString, segments: [InlineSegment])
    case toolGroup(id: String, tools: [ToolCall])
    case xml(id: String, nodes: [XMLNode])

    var id: String {
        switch self {
        case .text(let id, _, _): return id
        case .code(let id, _, _, _): return id
        case .table(let id, _): return id
        case .blockquote(let id, _): return id
        case .horizontalRule(let id): return id
        case .header(let id, _, _, _): return id
        case .toolGroup(let id, _): return id
        case .xml(let id, _): return id
        }
    }

    var renderSignature: String {
        switch self {
        case .text(let id, let content, _):
            let value = String(content.characters)
            return "text:\(id):\(value.count):\(value.hashValue)"
        case .code(let id, let content, let language, let isComplete):
            return "code:\(id):\(content.count):\(content.hashValue):\(language ?? ""):\(isComplete)"
        case .table(let id, let rows):
            let value = rows.flatMap(\.self).joined(separator: "|")
            return "table:\(id):\(rows.count):\(value.hashValue)"
        case .blockquote(let id, let content):
            return "blockquote:\(id):\(content.count):\(content.hashValue)"
        case .horizontalRule(let id):
            return "hr:\(id)"
        case .header(let id, let level, let content, _):
            let value = String(content.characters)
            return "header:\(id):\(level):\(value.count):\(value.hashValue)"
        case .toolGroup(let id, let tools):
            let value = tools.map { "\($0.toolId):\($0.state.rawValue):\($0.name)" }.joined(separator: "|")
            return "tools:\(id):\(value.hashValue)"
        case .xml(let id, let nodes):
            let value = String(describing: nodes)
            return "xml:\(id):\(value.hashValue)"
        }
    }

    func prefixed(_ prefix: String) -> StreamingBlock {
        switch self {
        case .text(let id, let a, let s): return .text(id: prefix + id, a, segments: s)
        case .code(let id, let c, let l, let comp): return .code(id: prefix + id, content: c, language: l, isComplete: comp)
        case .table(let id, let r): return .table(id: prefix + id, rows: r)
        case .blockquote(let id, let c): return .blockquote(id: prefix + id, content: c)
        case .horizontalRule(let id): return .horizontalRule(id: prefix + id)
        case .header(let id, let l, let c, let s): return .header(id: prefix + id, level: l, content: c, segments: s)
        case .toolGroup(let id, let t): return .toolGroup(id: prefix + id, tools: t)
        case .xml(let id, let n): return .xml(id: prefix + id, nodes: n)
        }
    }
}
