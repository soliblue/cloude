//
//  StreamingBlock.swift
//  Cloude

import Foundation

enum StreamingBlock: Identifiable {
    case text(id: String, AttributedString, segments: [InlineSegment])
    case code(id: String, content: String, language: String?, isComplete: Bool)
    case table(id: String, rows: [[String]])
    case blockquote(id: String, content: String)
    case horizontalRule(id: String)

    var id: String {
        switch self {
        case .text(let id, _, _): return id
        case .code(let id, _, _, _): return id
        case .table(let id, _): return id
        case .blockquote(let id, _): return id
        case .horizontalRule(let id): return id
        }
    }
}
