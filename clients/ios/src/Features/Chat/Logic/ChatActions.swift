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
        message.timelineOrder = nextTimelineOrder(sessionId: sessionId, context: context)
        context.insert(message)
        return message
    }

    @MainActor
    @discardableResult
    static func importHistory(
        _ history: [String: Any], session: Session, context: ModelContext, requiringRemoteFollow: Bool = false,
        recordTimeline: Bool = false, beforeApply: () -> Bool = { true }, afterApply: () -> Bool = { true }
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
        if recordTimeline && !(history["turns"] is [[String: Any]]) { return false }
        let turns = history["turns"] as? [[String: Any]] ?? []
        let images = await resolveHistoryImages(turns, existing: existing)
        if Task.isCancelled || session.isDeleted || session.connectionKey != connection || session.isStreaming
            || (requiringRemoteFollow && !session.followsRemote)
        {
            return false
        }
        let turnIds = turns.compactMap { $0["id"] as? String }
        let recordsTimeline =
            recordTimeline && turnIds.count == turns.count
            && Set(turnIds).count == turnIds.count && turnIds.allSatisfy(ChatHistoryPage.validIdentity)
        if recordTimeline && !recordsTimeline { return false }
        var records: [String: ChatHistoryTurnRecord] = [:]
        var timelineOrders: [String: Int64] = [:]
        if recordsTimeline {
            var itemIds: Set<String> = []
            for turn in turns {
                guard let status = turn["status"] as? String,
                    ["completed", "interrupted", "failed", "inProgress"].contains(status),
                    turn["itemsView"] == nil || turn["itemsView"] as? String == "full",
                    let items = turn["items"] as? [[String: Any]]
                else { return false }
                for item in items {
                    guard let id = item["id"] as? String, ChatHistoryPage.validIdentity(id),
                        itemIds.insert(id).inserted,
                        let type = item["type"] as? String, ChatHistoryPage.validIdentity(type)
                    else { return false }
                }
            }
            guard
                let stored = try? context.fetch(
                    FetchDescriptor<ChatHistoryTurnRecord>(
                        predicate: #Predicate { $0.sessionId == sessionId }))
            else { return false }
            let ordered = stored.sorted { $0.order < $1.order }
            guard ordered.count <= turnIds.count,
                Array(turnIds.prefix(ordered.count)) == ordered.map(\.turnId),
                Set(ordered.map(\.order)).count == ordered.count
            else { return false }
            for record in ordered {
                records[record.turnId] = record
                timelineOrders[record.turnId] = record.order
            }
            if ordered.isEmpty {
                for (index, id) in turnIds.enumerated() {
                    timelineOrders[id] = Int64(index - max(0, turnIds.count - 1))
                }
            } else if ordered.count < turnIds.count {
                let next = nextTimelineOrder(sessionId: sessionId, context: context)
                let count = turnIds.count - ordered.count
                guard next > ordered.last!.order, next <= Int64.max - Int64(count - 1) else { return false }
                for (index, id) in turnIds.dropFirst(ordered.count).enumerated() {
                    timelineOrders[id] = next + Int64(index)
                }
            }
        }
        if Task.isCancelled || !beforeApply() { return false }
        var order = 0
        for turn in turns {
            let turnId = recordsTimeline ? turn["id"] as? String : nil
            let timelineOrder = turnId.flatMap { timelineOrders[$0] }
            if let turnId, let timelineOrder {
                let status = turn["status"] as? String ?? "completed"
                if let record = records[turnId] {
                    record.status = status
                } else {
                    context.insert(
                        ChatHistoryTurnRecord(
                            sessionId: sessionId, turnId: turnId, order: timelineOrder, status: status))
                }
            }
            let items = turn["items"] as? [[String: Any]] ?? []
            let reviewTexts = Set(
                items.filter { $0["type"] as? String == "agentMessage" }
                    .compactMap { $0["text"] as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            for offset in stride(from: 0, to: items.count, by: 100) {
                if !recordsTimeline
                    && (Task.isCancelled || session.isDeleted || session.connectionKey != connection
                        || session.isStreaming
                        || (requiringRemoteFollow && !session.followsRemote))
                {
                    return false
                }
                applyHistoryItems(
                    Array(items[offset..<min(offset + 100, items.count)]), turnStatus: turn["status"] as? String,
                    turnId: turnId, timelineOrder: timelineOrder, createdAt: history["createdAt"] as? Double ?? 0,
                    session: session, context: context, existing: &existing, existingCalls: &existingCalls,
                    resolvedImages: images, order: &order, itemOffset: offset, reviewTexts: reviewTexts)
                if !recordsTimeline { await Task.yield() }
            }
        }
        SessionActions.setRemoteRunning(
            (history["status"] as? [String: Any])?["type"].map { ($0 as? String) == "active" }
                ?? (turns.last?["status"] as? String == "inProgress"), for: session)
        SessionActions.setRemoteTurnStatus(turns.last?["status"] as? String, for: session)
        return afterApply()
    }

    @MainActor
    @discardableResult
    static func importPage(
        _ page: ChatHistoryPage, direction: ChatHistoryPageDirection, session: Session, context: ModelContext,
        beforeApply: () -> Bool = { true }, afterApply: () -> Bool = { true }
    ) async -> Bool {
        if Task.isCancelled || session.isDeleted || session.isStreaming { return false }
        let connection = session.connectionKey
        let payloads = page.turns.compactMap {
            try? JSONSerialization.jsonObject(with: $0.fullPayloadData) as? [String: Any]
        }
        guard payloads.count == page.turns.count,
            zip(payloads, page.turns).allSatisfy({
                $0.0["id"] as? String == $0.1.id && $0.0["status"] as? String == $0.1.status
            }),
            let data = try? JSONSerialization.data(withJSONObject: ["threadId": page.threadId, "data": payloads]),
            let validated = await ChatHistoryPage.decode(data)
        else { return false }
        if Task.isCancelled || session.isDeleted || session.connectionKey != connection || session.isStreaming {
            return false
        }
        let turns = direction == .newer ? validated.turns : Array(validated.turns.reversed())
        let turnIds = turns.map(\.id)
        let sessionId = session.id
        guard
            let records = try? context.fetch(
                FetchDescriptor<ChatHistoryTurnRecord>(
                    predicate: #Predicate { $0.sessionId == sessionId && turnIds.contains($0.turnId) }))
        else { return false }
        var oldestQuery = FetchDescriptor<ChatHistoryTurnRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }, sortBy: [SortDescriptor(\.order)])
        oldestQuery.fetchLimit = 1
        var newestQuery = FetchDescriptor<ChatHistoryTurnRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }, sortBy: [SortDescriptor(\.order, order: .reverse)])
        newestQuery.fetchLimit = 1
        guard let oldest = try? context.fetch(oldestQuery), let newest = try? context.fetch(newestQuery) else {
            return false
        }
        var stored: [String: ChatHistoryTurnRecord] = [:]
        for record in records {
            if stored[record.turnId] != nil { return false }
            stored[record.turnId] = record
        }
        let known = turns.compactMap { stored[$0.id]?.order }
        if zip(known, known.dropFirst()).contains(where: { $0 >= $1 }) { return false }
        let unknownCount = turns.filter { stored[$0.id] == nil }.count
        var nextOrder: Int64
        switch direction {
        case .initial:
            if !oldest.isEmpty && known.last != newest.first?.order { return false }
            if !oldest.isEmpty && unknownCount > 0 {
                guard let last = known.last, last == newest.first?.order,
                    let firstUnknown = turns.firstIndex(where: { stored[$0.id] == nil }),
                    !turns[firstUnknown...].contains(where: { stored[$0.id] != nil })
                else { return false }
                let bound = max(
                    newest.first?.order ?? -1, nextTimelineOrder(sessionId: sessionId, context: context) - 1)
                if bound > Int64.max - Int64(unknownCount) { return false }
                nextOrder = bound + 1
            } else {
                nextOrder = -Int64(max(0, turns.count - 1))
            }
        case .older:
            if let firstKnown = turns.firstIndex(where: { stored[$0.id] != nil }),
                turns[firstKnown...].contains(where: { stored[$0.id] == nil })
            {
                return false
            }
            if unknownCount > 0, let first = known.first, first != oldest.first?.order { return false }
            let bound = oldest.first?.order ?? 0
            if bound < Int64.min + Int64(unknownCount) { return false }
            nextOrder = bound - Int64(unknownCount)
        case .newer:
            if let firstUnknown = turns.firstIndex(where: { stored[$0.id] == nil }),
                turns[firstUnknown...].contains(where: { stored[$0.id] != nil })
            {
                return false
            }
            if unknownCount > 0, let last = known.last, last != newest.first?.order { return false }
            let bound = max(newest.first?.order ?? -1, nextTimelineOrder(sessionId: sessionId, context: context) - 1)
            if bound > Int64.max - Int64(unknownCount) { return false }
            nextOrder = bound + (unknownCount > 0 ? 1 : 0)
        }
        var orders: [String: Int64] = [:]
        for turn in turns {
            if let record = stored[turn.id] {
                orders[turn.id] = record.order
            } else {
                orders[turn.id] = nextOrder
                if nextOrder < Int64.max { nextOrder += 1 }
            }
        }
        let ordered = turns.compactMap { orders[$0.id] }
        if zip(ordered, ordered.dropFirst()).contains(where: { $0 >= $1 }) { return false }
        let itemIds = payloads.flatMap { ($0["items"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String } }
        let turnKeys = turnIds.map { Optional($0) }
        let itemKeys = itemIds.map { Optional($0) }
        guard
            let messages = try? context.fetch(
                FetchDescriptor<ChatMessage>(
                    predicate: #Predicate {
                        $0.sessionId == sessionId
                            && (turnKeys.contains($0.remoteTurnId) || itemKeys.contains($0.remoteItemId))
                    }))
        else { return false }
        var existing: [String: ChatMessage] = [:]
        for message in messages {
            guard let id = message.remoteItemId, existing[id] == nil else { return false }
            existing[id] = message
        }
        for turn in payloads {
            for item in turn["items"] as? [[String: Any]] ?? [] {
                if let id = item["id"] as? String, let assigned = existing[id]?.remoteTurnId,
                    assigned != turn["id"] as? String
                {
                    return false
                }
            }
        }
        let messageIds = messages.map(\.id)
        let callIds = itemIds.map { sessionId.uuidString + ":" + $0 }
        guard
            let calls = try? context.fetch(
                FetchDescriptor<ChatToolCall>(
                    predicate: #Predicate {
                        $0.sessionId == sessionId && (messageIds.contains($0.messageId) || callIds.contains($0.id))
                    }))
        else { return false }
        var existingCalls: [String: ChatToolCall] = [:]
        for call in calls {
            if existingCalls[call.id] != nil { return false }
            existingCalls[call.id] = call
        }
        let images = await resolveHistoryImages(payloads, existing: existing)
        if Task.isCancelled || session.isDeleted || session.connectionKey != connection || session.isStreaming {
            return false
        }
        if Task.isCancelled || !beforeApply() { return false }
        let currentItemIds = Set(itemIds)
        let removed = messages.filter { !currentItemIds.contains($0.remoteItemId ?? "") }
        let removedIds = Set(removed.map(\.id))
        for call in calls where removedIds.contains(call.messageId) {
            existingCalls.removeValue(forKey: call.id)
            context.delete(call)
        }
        for message in removed {
            if let id = message.remoteItemId { existing.removeValue(forKey: id) }
            context.delete(message)
        }
        var order = 0
        for turn in payloads {
            let id = turn["id"] as! String
            let status = turn["status"] as! String
            if let record = stored[id] {
                record.status = status
            } else {
                context.insert(
                    ChatHistoryTurnRecord(sessionId: sessionId, turnId: id, order: orders[id]!, status: status))
            }
            applyHistoryItems(
                turn["items"] as! [[String: Any]], turnStatus: status, turnId: id,
                timelineOrder: orders[id], createdAt: turn["startedAt"] as? Double ?? 0,
                session: session, context: context, existing: &existing, existingCalls: &existingCalls,
                resolvedImages: images, order: &order)
        }
        return afterApply()
    }

    @MainActor
    private static func resolveHistoryImages(
        _ turns: [[String: Any]], existing: [String: ChatMessage]
    ) async -> [String: (sources: [String], images: [Data])] {
        var result: [String: (sources: [String], images: [Data])] = [:]
        for turn in turns {
            for item in turn["items"] as? [[String: Any]] ?? [] where item["type"] as? String == "userMessage" {
                if Task.isCancelled { return result }
                if let id = item["id"] as? String {
                    let inputs = (item["content"] as? [[String: Any]] ?? []).compactMap { part -> (String, String)? in
                        if let type = part["type"] as? String, type == "image" || type == "localImage" {
                            return (type, part[type == "localImage" ? "path" : "url"] as? String ?? "")
                        }
                        return nil
                    }
                    if !inputs.isEmpty {
                        result[id] = await ChatHistoryImage.resolve(
                            inputs, sources: existing[id]?.imageSources ?? [], images: existing[id]?.imagesData ?? [])
                    }
                }
            }
        }
        return result
    }

    @MainActor
    private static func applyHistoryItems(
        _ items: [[String: Any]], turnStatus: String?, turnId: String?, timelineOrder: Int64?, createdAt: Double,
        session: Session, context: ModelContext, existing: inout [String: ChatMessage],
        existingCalls: inout [String: ChatToolCall], resolvedImages: [String: (sources: [String], images: [Data])],
        order: inout Int, itemOffset: Int = 0, reviewTexts: Set<String>? = nil
    ) {
        let assistantTexts =
            reviewTexts
            ?? Set(
                items.filter { $0["type"] as? String == "agentMessage" }
                    .compactMap { $0["text"] as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        for (index, item) in items.enumerated() {
            let itemIndex = index + itemOffset
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
                message.createdAt = Date(timeIntervalSince1970: createdAt + Double(order) / 1000)
                message.model =
                    type == "userMessage" || item["source"] as? String == "userShell"
                    ? nil : "Codex"
                context.insert(message)
                existing[remoteId] = message
            }
            if let turnId, let timelineOrder {
                message.remoteTurnId = turnId
                message.timelineOrder = timelineOrder
                message.timelineItemOrder = itemIndex
            }
            if item["source"] as? String == "userShell", message.model != nil { message.model = nil }
            if type == "userMessage" {
                let content = (item["content"] as? [[String: Any]]) ?? []
                let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if message.text != text { message.text = text }
                if let images = resolvedImages[remoteId], !images.sources.isEmpty {
                    var merged = images.images
                    let cached = zip(message.imageSources ?? [], message.imagesData)
                    var remaining = 20_971_520 - merged.reduce(0, { $0 + $1.count })
                    for index in merged.indices where merged[index].isEmpty {
                        if let data = cached.first(where: { $0.0 == images.sources[index] && !$0.1.isEmpty })?.1,
                            data.count <= remaining
                        {
                            merged[index] = data
                            remaining -= data.count
                        }
                    }
                    if message.imageSources != images.sources { message.imageSources = images.sources }
                    if message.imagesData != merged { message.imagesData = merged }
                }
            } else if type == "agentMessage" || type == "plan" {
                let text = item["text"] as? String ?? ""
                if message.text != text { message.text = text }
                if type == "plan" { message.planIsComplete = turnStatus != "inProgress" }
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
                let toolOrder = timelineOrder == nil ? order : itemIndex
                if let call = existingCalls[callId]
                    ?? existingCalls[remoteId].flatMap({
                        $0.sessionId == session.id && $0.messageId == message.id ? $0 : nil
                    })
                {
                    existingCalls[callId] = call
                    if call.result != result { call.result = result }
                    if call.state != state { call.state = state }
                    if call.order != toolOrder { call.order = toolOrder }
                    let input = ChatToolCall.prettyJSON(item)
                    if call.inputJSON != input {
                        call.inputJSON = input
                        call.inputSummary = ChatToolCall.summarize(name: name, input: item)
                        call.cachedInput = nil
                    }
                } else {
                    let call = ChatToolCall(
                        id: callId, messageId: message.id, sessionId: session.id, name: name,
                        inputSummary: ChatToolCall.summarize(name: name, input: item),
                        inputJSON: ChatToolCall.prettyJSON(item), result: result, state: state, order: toolOrder)
                    context.insert(call)
                    existingCalls[callId] = call
                    message.hasToolCalls = true
                }
            }
            order += 1
        }
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
        if context.container.schema.entities.contains(where: { $0.name == "ChatHistoryTurnRecord" }) {
            for record
                in (try? context.fetch(
                    FetchDescriptor<ChatHistoryTurnRecord>(
                        predicate: #Predicate { $0.sessionId == sessionId }))) ?? []
            {
                context.delete(record)
            }
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
            message.timelineOrder = original.timelineOrder
            message.timelineItemOrder = original.timelineItemOrder
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
    static func nextTimelineOrder(sessionId: UUID, context: ModelContext) -> Int64 {
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timelineOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        var order = (try? context.fetch(descriptor).first?.timelineOrder) ?? 0
        if context.container.schema.entities.contains(where: { $0.name == "ChatHistoryTurnRecord" }) {
            var records = FetchDescriptor<ChatHistoryTurnRecord>(
                predicate: #Predicate { $0.sessionId == sessionId }, sortBy: [SortDescriptor(\.order, order: .reverse)])
            records.fetchLimit = 1
            if let maximum = try? context.fetch(records).first?.order { order = max(order, maximum) }
        }
        return order < Int64.max ? order + 1 : order
    }

    @MainActor
    static func beginAssistant(sessionId: UUID, context: ModelContext) -> ChatMessage {
        let message = ChatMessage(sessionId: sessionId, role: .assistant, state: .streaming)
        message.timelineOrder = nextTimelineOrder(sessionId: sessionId, context: context)
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
