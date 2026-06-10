import SwiftData
import SwiftUI

struct ChatViewMessageListRowToolPillList: View {
    let session: Session
    let messageIds: [UUID]
    @Query private var toolCalls: [ChatToolCall]
    @State private var selected: ChatToolCall?

    init(session: Session, messageIds: [UUID]) {
        self.session = session
        self.messageIds = messageIds
        _toolCalls = Query(
            filter: #Predicate<ChatToolCall> {
                messageIds.contains($0.messageId) && $0.parentToolUseId == nil
            },
            sort: [SortDescriptor(\.order), SortDescriptor(\.id)]
        )
    }

    var body: some View {
        if !toolCalls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    ForEach(toolCalls) { toolCall in
                        ChatViewMessageListRowToolPillListRow(toolCall: toolCall) {
                            selected = toolCall
                        }
                    }
                }
                .transaction { $0.animation = nil }
            }
            .contentMargins(.horizontal, ThemeTokens.Spacing.m, for: .scrollContent)
            .padding(.horizontal, -ThemeTokens.Spacing.m)
            .scrollClipDisabled()
            .sheet(item: $selected) { toolCall in
                ChatViewMessageListRowToolPillSheet(session: session, toolCall: toolCall)
            }
        }
    }
}
