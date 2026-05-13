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
        _ message: ChatMessage, finalText: String, toolUses: [DecodedToolUse], model: String?,
        context: ModelContext
    ) {
        message.text = finalText
        message.state = .complete
        if let model { message.model = model }
        let existingIds = Set(message.toolCalls.map { $0.id })
        var nextTopOrder = (message.toolCalls.map { $0.order }.max() ?? -1) + 1
        var nextChildOrder: [String: Int] = [:]
        for use in toolUses where !existingIds.contains(use.id) {
            let order: Int
            if let parentId = use.parentToolUseId {
                if nextChildOrder[parentId] == nil {
                    let descriptor = FetchDescriptor<ChatToolCall>(
                        predicate: #Predicate<ChatToolCall> { $0.parentToolUseId == parentId }
                    )
                    let siblings = (try? context.fetch(descriptor)) ?? []
                    nextChildOrder[parentId] = (siblings.map { $0.order }.max() ?? -1) + 1
                }
                order = nextChildOrder[parentId]!
                nextChildOrder[parentId]! += 1
            } else {
                order = nextTopOrder
                nextTopOrder += 1
            }
            let call = ChatToolCall(
                id: use.id,
                name: use.name,
                inputSummary: use.inputSummary,
                inputJSON: use.inputJSON,
                order: order,
                parentToolUseId: use.parentToolUseId
            )
            call.message = message
            context.insert(call)
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
    static func applyCost(sessionId: UUID, costUsd: Double, context: ModelContext) {
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "assistant"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let latest = try? context.fetch(descriptor).first {
            let prior = latest.costUsd ?? 0
            latest.costUsd = costUsd
            let sessionDescriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId }
            )
            if let session = try? context.fetch(sessionDescriptor).first {
                session.totalCostUsd += costUsd - prior
            }
        }
    }

    @MainActor
    static func finishStreaming(_ message: ChatMessage?, isFailed: Bool = false) {
        if let message, message.state == .streaming {
            message.state = isFailed ? .failed : .complete
        }
    }
}
