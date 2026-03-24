// MessageBubble+LiveWrapper.swift

import SwiftUI
import CloudeShared

struct ObservedMessageBubble: View {
    let message: ChatMessage
    @ObservedObject var output: ConversationOutput
    var skills: [Skill] = []
    var isCompact: Bool = false
    var onToggleCollapse: (() -> Void)?

    var body: some View {
        MessageBubble(
            message: message,
            skills: skills,
            liveOutput: output.liveMessageId == message.id ? output : nil,
            onToggleCollapse: onToggleCollapse,
            isCompact: isCompact
        )
    }
}
