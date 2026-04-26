import SwiftUI

struct ChatViewMessageListRowToolPillSheetGlob: View {
    let toolCall: ChatToolCall

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let pattern = toolCall.parsedInput["pattern"] as? String, !pattern.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(
                    title: "Pattern", icon: "folder.badge.questionmark"
                ) {
                    Text(pattern)
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            if let path = toolCall.parsedInput["path"] as? String, !path.isEmpty {
                ChatViewMessageListRowToolPillSheetChip(
                    icon: "folder", label: path, tint: ChatToolKind.glob.color)
            }
        }
    }
}
