import SwiftUI

struct ChatViewMessageListRowToolPillSheetAgent: View {
    let toolCall: ChatToolCall

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let description = toolCall.parsedInput["description"] as? String,
                !description.isEmpty
            {
                Text(description)
                    .appFont(size: ThemeTokens.Text.l, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let prompt = toolCall.parsedInput["prompt"] as? String, !prompt.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Prompt", icon: "text.alignleft") {
                    ChatViewMessageListRowMarkdown(text: prompt)
                }
            }
            if let result = toolCall.result, !result.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(
                    title: toolCall.state == .failed ? "Error" : "Output",
                    icon: "arrow.left.circle"
                ) {
                    ChatViewMessageListRowMarkdown(text: result)
                        .foregroundColor(toolCall.state == .failed ? ThemeColor.danger : .primary)
                }
            }
        }
    }
}
