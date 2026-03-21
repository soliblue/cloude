import SwiftUI

extension MainChatView {
    func exportConversation(_ conversation: Conversation) {
        var lines: [String] = []
        let messages = conversationStore.messages(for: conversation)

        for message in messages {
            if message.isUser {
                lines.append("**User**: \(message.text)")
            } else {
                var parts: [String] = []
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { parts.append(text) }
                for tool in message.toolCalls {
                    let input = tool.input ?? ""
                    parts.append("> **\(tool.name)**: \(input)")
                }
                lines.append(parts.joined(separator: "\n\n"))
            }
        }

        let markdown = lines.joined(separator: "\n\n---\n\n")
        UIPasteboard.general.string = markdown
    }

    func environmentDisconnected(for conversation: Conversation?) -> Bool {
        if let envId = conversation?.environmentId {
            return !(connection.connection(for: envId)?.isAuthenticated ?? false)
        }
        return false
    }

    func refreshConversation(for window: ChatWindow) {
        guard let convId = window.conversationId,
              let conv = conversationStore.conversation(withId: convId),
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        refreshingSessionIds.insert(sessionId)
        let messages = conversationStore.messages(for: conv)
        if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
            conversationStore.truncateMessages(for: conv, from: lastUserIndex + 1)
        }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conv.environmentId)
    }
}
