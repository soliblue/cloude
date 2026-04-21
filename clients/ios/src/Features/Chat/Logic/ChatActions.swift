import Foundation
import SwiftData

enum ChatActions {
    @MainActor
    static func addUserMessage(
        sessionId: UUID, text: String, images: [Data], context: ModelContext
    ) -> ChatMessage {
        let message = ChatMessage(
            sessionId: sessionId, role: .user, text: text, images: images, state: .complete)
        context.insert(message)
        return message
    }

    @MainActor
    static func beginAssistant(sessionId: UUID, context: ModelContext) -> ChatMessage {
        let message = ChatMessage(sessionId: sessionId, role: .assistant, state: .streaming)
        context.insert(message)
        return message
    }

    @MainActor
    static func completeAssistant(
        _ message: ChatMessage, finalText: String, toolUses: [DecodedToolUse],
        context: ModelContext
    ) {
        message.text = finalText
        message.state = .complete
        let existingIds = Set(message.toolCalls.map { $0.id })
        var nextOrder = (message.toolCalls.map { $0.order }.max() ?? -1) + 1
        for use in toolUses where !existingIds.contains(use.id) {
            let call = ChatToolCall(
                id: use.id,
                name: use.name,
                inputSummary: use.inputSummary,
                inputJSON: use.inputJSON,
                order: nextOrder
            )
            call.message = message
            context.insert(call)
            nextOrder += 1
        }
    }

    @MainActor
    static func applyToolResult(
        toolUseId: String, text: String, isError: Bool, context: ModelContext
    ) {
        let descriptor = FetchDescriptor<ChatToolCall>(
            predicate: #Predicate<ChatToolCall> { $0.id == toolUseId }
        )
        if let call = try? context.fetch(descriptor).first {
            call.result = text
            call.state = isError ? .failed : .succeeded
        }
    }

    @MainActor
    static func finishStreaming(_ message: ChatMessage?, isFailed: Bool = false) {
        if let message, message.state == .streaming {
            message.state = isFailed ? .failed : .complete
        }
    }
}
