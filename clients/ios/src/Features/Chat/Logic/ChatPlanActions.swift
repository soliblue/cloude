import Foundation
import SwiftData

@MainActor enum ChatPlanActions {
    @discardableResult
    static func apply(
        itemId: String, text: String, delta: Bool, completed: Bool, seq: Int,
        sessionId: UUID, context: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.sessionId == sessionId && $0.remoteItemId == itemId })
        let existing = try? context.fetch(descriptor).first
        if (existing?.planEventSeq ?? -1) < seq && !(existing?.planIsComplete == true && !completed) {
            let message = existing ?? ChatMessage(sessionId: sessionId, role: .assistant)
            if existing == nil {
                message.remoteItemId = itemId
                var latest = FetchDescriptor<ChatMessage>(
                    predicate: #Predicate { $0.sessionId == sessionId },
                    sortBy: [SortDescriptor(\.timelineOrder, order: .reverse)])
                latest.fetchLimit = 1
                var order = (try? context.fetch(latest).first?.timelineOrder) ?? 0
                if context.container.schema.entities.contains(where: { $0.name == "ChatHistoryTurnRecord" }) {
                    var records = FetchDescriptor<ChatHistoryTurnRecord>(
                        predicate: #Predicate { $0.sessionId == sessionId },
                        sortBy: [SortDescriptor(\.order, order: .reverse)])
                    records.fetchLimit = 1
                    if let maximum = try? context.fetch(records).first?.order { order = max(order, maximum) }
                }
                message.timelineOrder = order < Int64.max ? order + 1 : order
                context.insert(message)
            }
            message.text = delta && !completed ? message.text + text : text
            message.planIsComplete = completed
            message.planEventSeq = seq
            message.state = .complete
            return true
        }
        return false
    }

    static func finish(sessionId: UUID, isFailed: Bool, context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.sessionId == sessionId && $0.planIsComplete == false })
        for message in (try? context.fetch(descriptor)) ?? [] {
            message.planIsComplete = true
            message.state = isFailed ? .failed : .complete
        }
    }
}
