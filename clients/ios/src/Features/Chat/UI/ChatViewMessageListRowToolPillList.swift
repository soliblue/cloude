import SwiftUI

struct ChatViewMessageListRowToolPillList: View {
    let toolCalls: [ChatToolCall]
    @State private var selected: ChatToolCall?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                ForEach(toolCalls) { toolCall in
                    ChatViewMessageListRowToolPillListRow(toolCall: toolCall) {
                        selected = toolCall
                    }
                }
            }
        }
        .sheet(item: $selected) { toolCall in
            ChatViewMessageListRowToolPillSheet(toolCall: toolCall)
        }
    }
}
