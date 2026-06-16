import SwiftUI

struct ChatViewMessageListRowToolPillSheetEditDiff: View {
    let oldText: String
    let newText: String
    let language: String
    @Environment(\.theme) private var theme

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Changes", icon: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(removedLines.indices, id: \.self) { index in
                    ChatViewMessageListRowToolPillSheetEditDiffRow(
                        text: removedLines[index], kind: .removed)
                }
                ForEach(addedLines.indices, id: \.self) { index in
                    ChatViewMessageListRowToolPillSheetEditDiffRow(text: addedLines[index], kind: .added)
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
