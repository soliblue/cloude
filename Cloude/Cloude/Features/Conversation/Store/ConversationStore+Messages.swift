import Foundation

extension ConversationStore {
    func addMessage(_ message: ChatMessage, to conversation: Conversation) {
        mutate(conversation.id) {
            $0.messages.append(message)
            $0.lastMessageAt = Date()
        }
    }

    func updateMessage(_ messageId: UUID, in conversation: Conversation, update: (inout ChatMessage) -> Void) {
        mutate(conversation.id) {
            if let msgIdx = $0.messages.firstIndex(where: { $0.id == messageId }) {
                update(&$0.messages[msgIdx])
            }
        }
    }

    func removeMessage(_ messageId: UUID, from conversation: Conversation) {
        mutate(conversation.id) {
            $0.messages.removeAll { $0.id == messageId }
        }
    }

    func insertLiveMessage(into conversation: Conversation) -> UUID {
        let message = ChatMessage(isUser: false, text: "")
        addMessage(message, to: conversation)
        return message.id
    }

    func queueMessage(_ message: ChatMessage, to conversation: Conversation) {
        mutate(conversation.id) { $0.pendingMessages.append(message) }
    }

    func removePendingMessage(_ messageId: UUID, from conversation: Conversation) {
        mutate(conversation.id) { $0.pendingMessages.removeAll { $0.id == messageId } }
    }

    func replaceMessages(_ conversation: Conversation, with messages: [ChatMessage]) {
        mutate(conversation.id) {
            let existingByServerUUID = Dictionary(
                $0.messages.compactMap { msg in msg.serverUUID.map { ($0, msg) } },
                uniquingKeysWith: { first, _ in first }
            )
            var merged = messages
            for i in merged.indices {
                let existing: ChatMessage?
                if let serverUUID = merged[i].serverUUID {
                    existing = existingByServerUUID[serverUUID]
                        ?? (i < $0.messages.count && $0.messages[i].isUser == merged[i].isUser ? $0.messages[i] : nil)
                } else if i < $0.messages.count, $0.messages[i].isUser == merged[i].isUser {
                    existing = $0.messages[i]
                } else {
                    existing = nil
                }
                if let existing {
                    merged[i].id = existing.id
                    if merged[i].durationMs == nil { merged[i].durationMs = existing.durationMs }
                    if merged[i].costUsd == nil { merged[i].costUsd = existing.costUsd }
                    if merged[i].model == nil { merged[i].model = existing.model }
                    if merged[i].toolCalls.count < existing.toolCalls.count {
                        AppLogger.connectionInfo("heuristic_counter=jsonl_lag_merge convId=\(conversation.id.uuidString) jsonl_tools=\(merged[i].toolCalls.count) client_tools=\(existing.toolCalls.count)")
                        merged[i].toolCalls = existing.toolCalls
                    }
                    if merged[i].imageBase64 == nil { merged[i].imageBase64 = existing.imageBase64 }
                    if merged[i].imageThumbnails == nil { merged[i].imageThumbnails = existing.imageThumbnails }
                }
            }
            $0.messages = merged
            if let lastTimestamp = messages.last?.timestamp {
                $0.lastMessageAt = lastTimestamp
            }
        }
    }

    func truncateMessages(for conversation: Conversation, from index: Int) {
        mutate(conversation.id) {
            if index < $0.messages.count {
                $0.messages.removeSubrange(index...)
            }
        }
    }

    func messages(for conversation: Conversation) -> [ChatMessage] {
        conversations.first(where: { $0.id == conversation.id })?.messages ?? []
    }
}
