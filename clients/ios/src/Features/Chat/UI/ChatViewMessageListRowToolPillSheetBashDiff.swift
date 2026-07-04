import SwiftUI

struct ChatViewMessageListRowToolPillSheetBashDiff: View {
    let text: String

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(title: "Diff", icon: "plus.forwardslash.minus") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(GitDiffParser.parse(text)) { line in
                    GitDiffSheetLine(line: line, language: "bash")
                }
            }
        }
    }
}
