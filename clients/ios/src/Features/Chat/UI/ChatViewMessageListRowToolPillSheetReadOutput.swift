import HighlightSwift
import SwiftUI

struct ChatViewMessageListRowToolPillSheetReadOutput: View {
    let text: String
    let language: String

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Content", icon: "doc.text") {
            ScrollView(.horizontal, showsIndicators: false) {
                CodeText(stripped)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .textSelection(.enabled)
            }
        }
    }

    private var stripped: String {
        text.components(separatedBy: "\n")
            .map { line in
                if let r = line.range(of: #"^\s*\d+\t"#, options: .regularExpression) {
                    return String(line[r.upperBound...])
                }
                if let r = line.range(of: #"^\s*\d+→"#, options: .regularExpression) {
                    return String(line[r.upperBound...])
                }
                return line
            }
            .joined(separator: "\n")
    }
}
