import Foundation
import SwiftData

enum ChatActions {
    @MainActor
    static func addUserMessage(
        sessionId: UUID, text: String, images: [Data], state: ChatMessage.State = .complete,
        references: [ChatReference] = [], reviewTarget: ChatReviewTarget? = nil, shellCommand: String? = nil,
        context: ModelContext
    ) -> ChatMessage {
        let message = ChatMessage(
            sessionId: sessionId, role: .user, text: text, images: images, state: state, references: references,
            reviewTarget: reviewTarget, shellCommand: shellCommand)
        context.insert(message)
        return message
    }

    @MainActor
    @discardableResult
    static func importHistory(
        _ history: [String: Any], session: Session, context: ModelContext, requiringRemoteFollow: Bool = false
    ) async -> Bool {
        if Task.isCancelled || session.isStreaming || (requiringRemoteFollow && !session.followsRemote) { return false }
        let sessionId = session.id
        let connection = session.connectionKey
        let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate<ChatMessage> { $0.sessionId == sessionId })
        var existing: [String: ChatMessage] = [:]
        for message in (try? context.fetch(descriptor)) ?? [] {
            if let id = message.remoteItemId { existing[id] = message }
        }
        let callDescriptor = FetchDescriptor<ChatToolCall>(
            predicate: #Predicate<ChatToolCall> { $0.sessionId == sessionId })
        var existingCalls: [String: ChatToolCall] = [:]
        for call in (try? context.fetch(callDescriptor)) ?? [] { existingCalls[call.id] = call }
        let turns = (history["turns"] as? [[String: Any]]) ?? []
        SessionActions.setRemoteRunning(
            (history["status"] as? [String: Any])?["type"].map { ($0 as? String) == "active" }
                ?? (turns.last?["status"] as? String == "inProgress"), for: session)
        SessionActions.setRemoteTurnStatus(turns.last?["status"] as? String, for: session)
        var order = 0
        for turn in turns {
            let items = (turn["items"] as? [[String: Any]]) ?? []
            let assistantTexts = Set(
                items.filter { $0["type"] as? String == "agentMessage" }.compactMap { $0["text"] as? String }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            for item in items {
                if Task.isCancelled || session.isDeleted || session.connectionKey != connection || session.isStreaming
                    || (requiringRemoteFollow && !session.followsRemote)
                {
                    return false
                }
                let type = item["type"] as? String ?? ""
                let remoteId = item["id"] as? String ?? "item-\(order)"
                if type == "exitedReviewMode", let review = item["review"] as? String,
                    assistantTexts.contains(review.trimmingCharacters(in: .whitespacesAndNewlines))
                {
                    if let duplicate = existing.removeValue(forKey: remoteId) { context.delete(duplicate) }
                    continue
                }
                let message =
                    existing[remoteId]
                    ?? ChatMessage(sessionId: session.id, role: type == "userMessage" ? .user : .assistant)
                if existing[remoteId] == nil {
                    message.remoteItemId = remoteId
                    message.createdAt = Date(
                        timeIntervalSince1970: (history["createdAt"] as? Double ?? 0) + Double(order) / 1000)
                    message.model =
                        type == "userMessage" || item["source"] as? String == "userShell"
                        ? nil : "Codex"
                    context.insert(message)
                    existing[remoteId] = message
                }
                if item["source"] as? String == "userShell", message.model != nil { message.model = nil }
                if type == "userMessage" {
                    let content = (item["content"] as? [[String: Any]]) ?? []
                    let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    if message.text != text { message.text = text }
                    let inputs = content.compactMap { part -> (String, String)? in
                        if let type = part["type"] as? String, type == "image" || type == "localImage" {
                            return (type, part[type == "localImage" ? "path" : "url"] as? String ?? "")
                        }
                        return nil
                    }
                    if !inputs.isEmpty {
                        let images = await ChatHistoryImage.resolve(
                            inputs, sources: message.imageSources ?? [], images: message.imagesData)
                        if Task.isCancelled || session.isDeleted || session.connectionKey != connection
                            || session.isStreaming
                            || (requiringRemoteFollow && !session.followsRemote)
                        {
                            return false
                        }
                        if !images.sources.isEmpty {
                            if message.imageSources != images.sources { message.imageSources = images.sources }
                            if message.imagesData != images.images { message.imagesData = images.images }
                        }
                    }
                } else if type == "agentMessage" || type == "plan" {
                    let text = item["text"] as? String ?? ""
                    if message.text != text { message.text = text }
                    if type == "plan" { message.planIsComplete = turn["status"] as? String != "inProgress" }
                } else if type == "enteredReviewMode" || type == "exitedReviewMode" {
                    let text =
                        type == "enteredReviewMode"
                        ? "Review started: \(item["review"] as? String ?? "changes")" : item["review"] as? String ?? ""
                    if message.text != text { message.text = text }
                } else if type == "reasoning" {
                    let thinking = (item["summary"] as? [String] ?? []).joined(separator: "\n")
                    if message.thinking != thinking { message.thinking = thinking }
                } else {
                    let name =
                        [
                            "commandExecution": "Bash", "fileChange": "Edit", "webSearch": "WebSearch",
                            "collabAgentToolCall": "Agent", "subAgentActivity": "Agent",
                        ][type] ?? item["tool"] as? String ?? type
                    let callId = session.id.uuidString + ":" + remoteId
                    let result =
                        type == "imageGeneration"
                        ? ChatToolCall.prettyJSON(item)
                        : item["aggregatedOutput"] as? String ?? ChatToolCall.prettyJSON(item["result"] ?? item)
                    let state: ChatToolCall.State =
                        (item["status"] as? String == "failed"
                            || (type == "imageGeneration" && item["failure"] is [String: Any])
                            || (item["exitCode"] as? Int).map { $0 != 0 } == true)
                        ? .failed : item["status"] as? String == "inProgress" ? .pending : .succeeded
                    if let call = existingCalls[callId] {
                        if call.result != result { call.result = result }
                        if call.state != state { call.state = state }
                    } else {
                        let call = ChatToolCall(
                            id: callId, messageId: message.id, sessionId: session.id, name: name,
                            inputSummary: ChatToolCall.summarize(name: name, input: item),
                            inputJSON: ChatToolCall.prettyJSON(item), result: result, state: state, order: order)
                        context.insert(call)
                        existingCalls[callId] = call
                        message.hasToolCalls = true
                    }
                }
                order += 1
                if order.isMultiple(of: 100) { await Task.yield() }
            }
        }
        return true
    }

    @MainActor
    static func discardHistory(sessionId: UUID, context: ModelContext) {
        for message
            in (try? context.fetch(
                FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == sessionId }))) ?? []
        {
            context.delete(message)
        }
        for call
            in (try? context.fetch(
                FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == sessionId }))) ?? []
        {
            context.delete(call)
        }
    }

    @MainActor
    static func attachRemoteImage(_ data: Data, source: String, to message: ChatMessage, context: ModelContext) -> Bool
    {
        let indexes = (message.imageSources ?? []).indices.filter {
            message.imageSources?[$0] == source && message.imagesData.indices.contains($0)
                && message.imagesData[$0].isEmpty
        }
        if !indexes.isEmpty, data.count * indexes.count <= 20_971_520 - message.imagesData.reduce(0, { $0 + $1.count })
        {
            for index in indexes { message.imagesData[index] = data }
            return (try? context.save()) != nil
        }
        return message.imageSources?.contains(source) == true && indexes.isEmpty
    }

    @MainActor
    static func copyHistory(from sourceId: UUID, to sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == sourceId }, sortBy: [SortDescriptor(\.createdAt)])
        for original in (try? context.fetch(descriptor)) ?? []
        where original.state == .complete && original.planIsComplete != false {
            let message = ChatMessage(
                sessionId: sessionId, role: original.role, text: original.text, images: original.imagesData)
            message.planIsComplete = original.planIsComplete
            message.imageSources = original.imageSources
            message.referencesData = original.referencesData
            message.reviewTargetData = original.reviewTargetData
            message.shellCommand = original.shellCommand
            message.createdAt = original.createdAt
            message.model = original.model
            message.thinking = original.thinking
            message.thinkingMs = original.thinkingMs
            message.thinkingRedacted = original.thinkingRedacted
            message.hasToolCalls = original.hasToolCalls
            context.insert(message)
            let originalId = original.id
            let calls = FetchDescriptor<ChatToolCall>(
                predicate: #Predicate<ChatToolCall> { $0.messageId == originalId })
            for call in (try? context.fetch(calls)) ?? [] {
                context.insert(
                    ChatToolCall(
                        id: sessionId.uuidString + ":" + call.id, messageId: message.id, sessionId: sessionId,
                        name: call.name, inputSummary: call.inputSummary, inputJSON: call.inputJSON,
                        result: call.result, state: call.state, order: call.order,
                        parentToolUseId: call.parentToolUseId.map { sessionId.uuidString + ":" + $0 }))
            }
        }
    }

    @MainActor
    static func removeQueued(_ message: ChatMessage, context: ModelContext) {
        if message.state == .queued {
            context.delete(message)
        }
    }

    @MainActor
    static func beginAssistant(sessionId: UUID, context: ModelContext) -> ChatMessage {
        let message = ChatMessage(sessionId: sessionId, role: .assistant, state: .streaming)
        context.insert(message)
        return message
    }

    @MainActor
    static func completeAssistant(
        _ message: ChatMessage, finalText: String, thinking: String = "", thinkingMs: Int = 0,
        thinkingRedacted: Bool = false, toolUses: [DecodedToolUse], model: String?,
        context: ModelContext
    ) {
        message.text = finalText
        message.thinking = thinking
        message.thinkingMs = thinkingMs
        message.thinkingRedacted = thinkingRedacted
        message.state = .complete
        if let model { message.model = model }
        if toolUses.isEmpty { return }
        let messageId = message.id
        let existingDescriptor = FetchDescriptor<ChatToolCall>(
            predicate: #Predicate<ChatToolCall> { $0.messageId == messageId }
        )
        let existingIds = Set(((try? context.fetch(existingDescriptor)) ?? []).map { $0.id })
        let sessionId = message.sessionId
        let topDescriptor = FetchDescriptor<ChatToolCall>(
            predicate: #Predicate<ChatToolCall> {
                $0.sessionId == sessionId && $0.parentToolUseId == nil
            }
        )
        let topCalls = (try? context.fetch(topDescriptor)) ?? []
        var nextTopOrder = (topCalls.map { $0.order }.max() ?? -1) + 1
        var nextChildOrder: [String: Int] = [:]
        var inserted = false
        for use in toolUses where !existingIds.contains(use.id) {
            let useId = use.id
            let useDescriptor = FetchDescriptor<ChatToolCall>(predicate: #Predicate<ChatToolCall> { $0.id == useId })
            if let existing = try? context.fetch(useDescriptor).first {
                existing.inputSummary = use.inputSummary
                existing.inputJSON = use.inputJSON
                existing.cachedInput = nil
            } else {
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
                    messageId: message.id,
                    sessionId: message.sessionId,
                    name: use.name,
                    inputSummary: use.inputSummary,
                    inputJSON: use.inputJSON,
                    order: order,
                    parentToolUseId: use.parentToolUseId
                )
                context.insert(call)
                inserted = true
            }
        }
        if inserted && !message.hasToolCalls { message.hasToolCalls = true }
    }

    @MainActor
    static func attachGitDelta(
        messageId: UUID, sessionId: UUID, changes: [GitChangeDTO], context: ModelContext
    ) {
        let descriptor = FetchDescriptor<ChatGitChange>(
            predicate: #Predicate<ChatGitChange> { $0.messageId == messageId }
        )
        for existing in (try? context.fetch(descriptor)) ?? [] { context.delete(existing) }
        for change in changes {
            context.insert(
                ChatGitChange(
                    messageId: messageId, sessionId: sessionId, path: change.path,
                    type: GitChangeType(rawValue: change.type) ?? .modified,
                    additions: change.additions ?? 0, deletions: change.deletions ?? 0))
        }
    }

    @MainActor
    static func appendToolOutput(toolUseId: String, text: String, context: ModelContext) {
        let descriptor = FetchDescriptor<ChatToolCall>(predicate: #Predicate<ChatToolCall> { $0.id == toolUseId })
        if let call = try? context.fetch(descriptor).first {
            call.result = (call.result ?? "") + text
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
