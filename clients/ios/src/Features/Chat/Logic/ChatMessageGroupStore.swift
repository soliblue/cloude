import Foundation

final class ChatMessageGroupStore {
    private var key: [UUID] = []
    private var cached: [ChatMessageGroup] = []

    func groups(for messages: [ChatMessage]) -> [ChatMessageGroup] {
        let newKey = messages.map(\.id)
        if newKey != key {
            var groups: [ChatMessageGroup] = []
            for message in messages {
                if groups.last?.messages.first?.role == message.role {
                    groups[groups.count - 1].messages.append(message)
                } else {
                    groups.append(ChatMessageGroup(groupId: message.id, messages: [message]))
                }
            }
            cached = groups
            key = newKey
        }
        return cached
    }
}
