import SwiftUI

struct ChatViewMessageListRowToolPillSheetEditDiff: View {
    let oldText: String
    let newText: String
    let language: String
    @Environment(\.theme) private var theme

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Changes", icon: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(removedLines, id: \.self) { line in
                    ChatViewMessageListRowToolPillSheetEditDiffRow(text: line, kind: .removed)
                }
                ForEach(addedLines, id: \.self) { line in
                    ChatViewMessageListRowToolPillSheetEditDiffRow(text: line, kind: .added)
                }
            }
        }
    }

    private var removedLines: [String] {
        oldText.components(separatedBy: "\n")
    }

    private var addedLines: [String] {
        newText.components(separatedBy: "\n")
    }
}
