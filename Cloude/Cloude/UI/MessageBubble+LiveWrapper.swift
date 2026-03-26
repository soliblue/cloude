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
        #if DEBUG
        let _ = DebugMetrics.log("LiveBubble", "render | live=\(output.liveMessageId == message.id) msgId=\(message.id.uuidString.prefix(6))")
        #endif
        MessageBubble(
            message: message,
            skills: skills,
            liveOutput: output.liveMessageId == message.id ? output : nil,
            onToggleCollapse: onToggleCollapse,
            isCompact: isCompact
        )
    }
}
