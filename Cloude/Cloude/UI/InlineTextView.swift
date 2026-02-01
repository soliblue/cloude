//
//  InlineTextView.swift
//  Cloude

import SwiftUI
import UIKit

enum InlineSegment: Identifiable, Equatable {
    case text(id: UUID = UUID(), AttributedString)
    case code(id: UUID = UUID(), String)
    case lineBreak(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _): return id
        case .lineBreak(let id): return id
        }
    }
}

struct InlineTextView: View {
    let segments: [InlineSegment]

    var body: some View {
        Text(buildAttributedString())
            .textSelection(.enabled)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize - 1, weight: .regular, design: .monospaced)
                attr.backgroundColor = Color(.secondarySystemFill)
                result.append(attr)
            case .lineBreak:
                result.append(AttributedString("\n"))
            }
        }
        return result
    }
}
