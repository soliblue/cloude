import SwiftUI
import CloudeShared

private struct LiveToolRenderState: Equatable {
    let name: String
    let input: String?
    let toolId: String
    let parentToolId: String?
    let textPosition: Int?
    let state: ToolCallState
    let editInfo: EditInfo?

    nonisolated init(_ toolCall: ToolCall) {
        name = toolCall.name
        input = toolCall.input
        toolId = toolCall.toolId
        parentToolId = toolCall.parentToolId
        textPosition = toolCall.textPosition
        state = toolCall.state
        editInfo = toolCall.editInfo
    }
}

struct ObservedMessageBubble: View, Equatable {
    let message: ChatMessage
    let output: ConversationOutput
    var skills: [Skill] = []
    var onRefresh: (() -> Void)?
    var isRefreshing: Bool = false
    var onSelectToolDetail: ((ToolDetailItem) -> Void)?

    @State private var liveText: String = ""
    @State private var liveToolCalls: [ToolCall] = []

    private var isLive: Bool { output.liveMessageId == message.id }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message &&
        lhs.output === rhs.output &&
        lhs.skills == rhs.skills &&
        lhs.isRefreshing == rhs.isRefreshing
    }

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
            if isLive && liveText != newText {
                liveText = newText
            }
        }
        .onReceive(output.$toolCalls) { newCalls in
            if isLive {
                let changed = liveToolCalls.count != newCalls.count || zip(liveToolCalls, newCalls).contains { LiveToolRenderState($0) != LiveToolRenderState($1) }
                if changed { liveToolCalls = newCalls }
            }
        }
    }
}
