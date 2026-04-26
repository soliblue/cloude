import SwiftUI

struct ChatViewMessageListRowToolPillSheetReadOutput: View {
    let text: String
    let language: String
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Content", icon: "doc.text") {
            ChatViewMessageListRowToolPillSheetExpandableText(
                text: Self.stripReadLineNumbers(text), tint: appAccent.color)
        }
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
