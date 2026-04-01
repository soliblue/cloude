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
    @State private var lastTextUpdate: CFTimeInterval = 0

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
            guard isLive else { return }
            let now = CACurrentMediaTime()
            if newText.count > 3000 {
                guard now - lastTextUpdate >= 0.05 || newText.count <= liveText.count else { return }
            }
            liveText = newText
            lastTextUpdate = now
        }
        .onReceive(output.$toolCalls) { newCalls in
            if isLive { liveToolCalls = newCalls }
        }
    }
}
