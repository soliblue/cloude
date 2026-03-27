// MessageBubble+LiveWrapper.swift

import SwiftUI
import CloudeShared

struct ObservedMessageBubble: View {
    let message: ChatMessage
    @ObservedObject var output: ConversationOutput
    var skills: [Skill] = []
    var isCompact: Bool = false
    var onToggleCollapse: (() -> Void)?

    private var isLive: Bool { output.liveMessageId == message.id }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("LiveBubble", "render | live=\(isLive) msgId=\(message.id.uuidString.prefix(6))")
        #endif
        MessageBubble(
            message: message,
            skills: skills,
            liveOutput: isLive ? output : nil,
            liveText: isLive ? output.text : nil,
            liveToolCalls: isLive ? output.toolCalls : nil,
            onToggleCollapse: onToggleCollapse,
            isCompact: isCompact
        )
    }
}
