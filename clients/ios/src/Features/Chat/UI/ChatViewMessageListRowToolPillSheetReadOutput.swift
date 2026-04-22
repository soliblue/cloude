import HighlightSwift
import SwiftUI

struct ChatViewMessageListRowToolPillSheetReadOutput: View {
    let text: String
    let language: String
    @State private var isExpanded = false
    private let previewLineCount = 15
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Content", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 0) {
                CodeText(displayed)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                if needsTruncation {
                    Divider().padding(.vertical, ThemeTokens.Spacing.xs)
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: ThemeTokens.Spacing.xs) {
                            Text(isExpanded ? "Show less" : "Show all \(lines.count) lines")
                                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                        }
                        .foregroundColor(appAccent.color)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stripped: String { Self.stripReadLineNumbers(text) }
    private var lines: [String] { stripped.components(separatedBy: "\n") }
    private var needsTruncation: Bool { lines.count > previewLineCount }
    private var displayed: String {
        if isExpanded || !needsTruncation { return stripped }
        return lines.prefix(previewLineCount).joined(separator: "\n")
    }

    static func stripReadLineNumbers(_ output: String) -> String {
        output.components(separatedBy: "\n")
            .map { line in
                if let range = line.range(of: #"^\s*\d+\t"#, options: .regularExpression) {
                    return String(line[range.upperBound...])
                }
                if let range = line.range(of: #"^\s*\d+→"#, options: .regularExpression) {
                    return String(line[range.upperBound...])
                }
                return line
            }
            .joined(separator: "\n")
    }
}
