import Foundation
import SwiftData

@main struct ChatReplayTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, ChatToolCall.self, ChatHistoryTurnRecord.self,
            configurations: ModelConfiguration(url: URL(fileURLWithPath: CommandLine.arguments[2])))
        let context = container.mainContext
        context.autosaveEnabled = false
        if CommandLine.arguments[1] == "write" {
            let endpoint = Endpoint()
            let session = Session(endpoint: endpoint)
            context.insert(endpoint)
            context.insert(session)
            session.lastSeq = 500
            try context.save()
            let user = ChatMessage(sessionId: session.id, role: .user, text: "Next turn")
            context.insert(user)
            ChatService.startNewTurn(session: session, message: user, context: context)
            precondition((try? ModelContext(container).fetch(FetchDescriptor<Session>()).first)?.lastSeq == -1)
            ChatService.apply(
                event: .assistantTextDelta(seq: 10, text: "Same reply", itemId: "first", turnId: "turn-new"),
                sessionId: session.id, context: context)
            ChatService.apply(
                event: .assistantFinal(
                    seq: 20, text: "Same reply", thinking: "", thinkingRedacted: false,
                    toolUses: [], model: nil, contextTokens: nil, itemId: "first", turnId: "turn-new"),
                sessionId: session.id, context: context)
            precondition(session.lastSeq == 20)
            try context.save()
            print("PASS new turn resets saved seq 500 before receiving/checkpointing seq 20")
        } else {
            let session = try context.fetch(FetchDescriptor<Session>()).first!
            precondition(session.lastSeq == 20)
            let original = try context.fetch(FetchDescriptor<ChatMessage>()).first { $0.remoteItemId == "first" }!
            let originalId = original.id
            ChatService.apply(event: .replay(seq: 0), sessionId: session.id, context: context)
            ChatService.apply(
                event: .assistantTextDelta(seq: 10, text: "Same reply", itemId: "first", turnId: "turn-new"),
                sessionId: session.id, context: context)
            precondition(ChatLiveStream.peek(for: session.id) == nil)
            ChatService.apply(
                event: .assistantFinal(
                    seq: 20, text: "Same reply", thinking: "", thinkingRedacted: false,
                    toolUses: [], model: nil, contextTokens: nil, itemId: "first", turnId: "turn-new"),
                sessionId: session.id, context: context)
            ChatService.apply(
                event: .assistantFinal(
                    seq: 21, text: "Same reply", thinking: "", thinkingRedacted: false,
                    toolUses: [], model: nil, contextTokens: nil, itemId: "second", turnId: "turn-new"),
                sessionId: session.id, context: context)
            for (index, id) in ["reasoning-a", "reasoning-b"].enumerated() {
                ChatService.apply(
                    event: .assistantThinkingDelta(
                        seq: 22 + index * 2, text: "Thought \(index)", itemId: id, turnId: "turn-new"),
                    sessionId: session.id, context: context)
                ChatService.apply(
                    event: .assistantFinal(
                        seq: 23 + index * 2, text: "", thinking: "Thought \(index)", thinkingRedacted: false,
                        toolUses: [], model: nil, contextTokens: nil, itemId: id, turnId: "turn-new"),
                    sessionId: session.id, context: context)
            }
            let messages = try context.fetch(FetchDescriptor<ChatMessage>()).filter { $0.role == .assistant }
            precondition(messages.count == 4)
            precondition(messages.filter { $0.text == "Same reply" }.count == 2)
            precondition(messages.first { $0.remoteItemId == "first" }?.id == originalId)
            precondition(
                messages.filter { !$0.thinking.isEmpty }.map(\.thinking).sorted() == ["Thought 0", "Thought 1"])
            precondition(messages.allSatisfy { $0.remoteTurnId == "turn-new" && $0.state == .complete })
            for _ in 0..<2 {
                ChatService.apply(
                    event: .assistantFinal(
                        seq: 30, text: "Legacy identical", thinking: "", thinkingRedacted: false,
                        toolUses: [], model: nil, contextTokens: nil),
                    sessionId: session.id, context: context)
            }
            precondition(
                (try? context.fetch(FetchDescriptor<ChatMessage>()))?.filter { $0.text == "Legacy identical" }.count
                    == 2)
            let claude = Data(
                #"{"seq":31,"event":{"type":"assistant","uuid":"claude-item","message":{"content":[{"type":"text","text":"Claude reply"}]}}}"#
                    .utf8)
            for _ in 0..<2 {
                ChatService.apply(event: ChatStreamEvent.decode(claude)!, sessionId: session.id, context: context)
            }
            precondition(
                (try? context.fetch(FetchDescriptor<ChatMessage>()))?.filter { $0.remoteItemId == "claude-item" }.count
                    == 1)
            ChatService.apply(
                event: .assistantFinal(
                    seq: 32, text: "", thinking: "", thinkingRedacted: false,
                    toolUses: [
                        DecodedToolUse(
                            id: "plan:turn-new", name: "TodoWrite", inputSummary: "Plan", inputJSON: "{}",
                            parentToolUseId: nil)
                    ],
                    model: nil, contextTokens: nil, turnId: "turn-new"),
                sessionId: session.id, context: context)
            let synthetic = try context.fetch(FetchDescriptor<ChatMessage>()).first { $0.hasToolCalls }!
            precondition(synthetic.remoteItemId == nil && synthetic.remoteTurnId == nil)
            let page = await ChatHistoryPage.decode(
                try JSONSerialization.data(withJSONObject: [
                    "threadId": "native-thread",
                    "data": [
                        [
                            "id": "turn-new", "status": "completed",
                            "items": [
                                ["id": "first", "type": "agentMessage", "text": "Same reply"],
                                ["id": "second", "type": "agentMessage", "text": "Same reply"],
                                ["id": "reasoning-a", "type": "reasoning", "summary": ["Thought 0"]],
                                ["id": "reasoning-b", "type": "reasoning", "summary": ["Thought 1"]],
                            ],
                        ]
                    ],
                ]))!
            let imported = await ChatActions.importPage(page, direction: .initial, session: session, context: context)
            precondition(imported)
            try context.save()
            precondition(
                (try? ModelContext(container).fetch(FetchDescriptor<ChatMessage>()))?.filter { $0.role == .assistant }
                    .count == 8)
            print(
                "PASS restart replay updates item identity once, preserves distinct equal responses/thoughts, retains unidentified text, and reuses Claude UUID"
            )
        }
    }
}
