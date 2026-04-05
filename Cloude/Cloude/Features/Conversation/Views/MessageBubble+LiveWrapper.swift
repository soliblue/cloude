import SwiftUI
import CloudeShared

struct ObservedMessageBubble: View {
    let message: ChatMessage
    let output: ConversationOutput
    var skills: [Skill] = []
    var onRefresh: (() -> Void)?
    var isRefreshing: Bool = false
    var onSelectToolDetail: ((ToolDetailItem) -> Void)?

    @State private var liveText: String = ""
    @State private var liveToolCalls: [ToolCall] = []

    private var isLive: Bool { output.liveMessageId == message.id }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("LiveBubble", "render | live=\(isLive) msgId=\(message.id.uuidString.prefix(6))")
        #endif
        MessageBubble(
            message: message,
            skills: skills,
            liveOutput: isLive ? output : nil,
            liveText: isLive ? liveText : nil,
            liveToolCalls: isLive ? liveToolCalls : nil,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing,
            onSelectToolDetail: onSelectToolDetail
        )
        .onReceive(output.$text) { newText in
            if isLive { liveText = newText }
        }
        .onReceive(output.$toolCalls) { newCalls in
            if isLive { liveToolCalls = newCalls }
        }
    }
}
