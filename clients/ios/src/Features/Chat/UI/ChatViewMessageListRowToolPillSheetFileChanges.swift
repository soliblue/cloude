import SwiftUI

struct ChatViewMessageListRowToolPillSheetFileChanges: View {
    let session: Session
    let toolCall: ChatToolCall

    var body: some View {
        LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            ForEach(toolCall.fileChanges) { change in
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Label(change.title, systemImage: change.symbol)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    if change.kind == "delete" {
                        Text(change.path)
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .textSelection(.enabled)
                    } else {
                        ChatViewMessageListRowToolPillSheetFileRow(
                            session: session, toolCall: toolCall, path: change.movedPath ?? change.path)
                    }
                    if let destination = change.movedPath {
                        Text("\(change.path) → \(destination)")
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    ChatViewMessageListRowToolPillSheetBashDiff(text: change.diff)
                }
            }
        }
    }
}
