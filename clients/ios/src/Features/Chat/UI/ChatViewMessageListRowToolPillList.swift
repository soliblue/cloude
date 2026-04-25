import SwiftUI

struct ChatViewMessageListRowToolPillList: View {
    let session: Session
    let toolCalls: [ChatToolCall]
    @State private var selected: ChatToolCall?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(toolCalls.filter { $0.parentToolUseId == nil }) { toolCall in
                    ChatViewMessageListRowToolPillListRow(toolCall: toolCall) {
                        selected = toolCall
                    }
                }
            }
        }
        .contentMargins(.horizontal, ThemeTokens.Spacing.m, for: .scrollContent)
        .padding(.horizontal, -ThemeTokens.Spacing.m)
        .scrollClipDisabled()
        .sheet(item: $selected) { toolCall in
            ChatViewMessageListRowToolPillSheet(session: session, toolCall: toolCall)
        }
    }
}
