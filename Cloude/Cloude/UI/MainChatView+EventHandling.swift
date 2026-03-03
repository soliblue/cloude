import SwiftUI
import CloudeShared

extension MainChatView {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .historySync(let sessionId, _), .historySyncError(let sessionId, _):
            refreshingSessionIds.remove(sessionId)

        case .authenticated:
            replayQueuedMessagesIfNeeded()

        case .transcription(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isBlank = trimmed.isEmpty ||
                trimmed.contains("blank_audio") ||
                trimmed.contains("blank audio") ||
                trimmed.contains("silence") ||
                trimmed.contains("no speech") ||
                trimmed.contains("inaudible") ||
                trimmed == "you" ||
                trimmed == "thanks for watching"
            if !isBlank {
                if inputText.isEmpty {
                    inputText = text
                } else {
                    inputText += " " + text
                }
            }
            AudioRecorder.clearPendingAudioFile()

        case .ttsAudio(let data, let messageId):
            TTSService.shared.playAudio(data, messageId: messageId)

        case .usageStats(let stats):
            guard awaitingUsageStats else { break }
            awaitingUsageStats = false
            usageStats = stats
            showUsageStats = true

        case .heartbeatConfig(let intervalMinutes, let unreadCount):
            conversationStore.handleHeartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount)

        case .fileSearchResults(let files, _):
            fileSearchResults = files

        case .suggestionsResult(let newSuggestions, let convId):
            guard let activeWindow = windowManager.activeWindow,
                  activeWindow.conversationId == convId,
                  inputText.isEmpty else { break }
            withAnimation(.easeIn(duration: 0.2)) {
                suggestions = newSuggestions
            }

        case .gitStatus(let path, let status):
            // MainChatView only uses this to annotate known working directories with their branch.
            if gitBranches[path] == nil, !status.branch.isEmpty {
                gitBranches[path] = status.branch
            }
            if let idx = pendingGitChecks.firstIndex(of: path) {
                pendingGitChecks.remove(at: idx)
            }
            checkNextGitDirectory()

        case .lastAssistantMessageCostUpdate(let convId, let costUsd):
            guard let conversation = conversationStore.conversation(withId: convId),
                  let lastAssistantMsg = conversation.messages.last(where: { !$0.isUser }) else { break }
            conversationStore.updateMessage(lastAssistantMsg.id, in: conversation) { msg in
                msg.costUsd = costUsd
            }

        default:
            break
        }
    }

    func replayQueuedMessagesIfNeeded() {
        for conv in conversationStore.conversations where !conv.pendingMessages.isEmpty {
            let output = connection.output(for: conv.id)
            if !output.isRunning {
                conversationStore.replayQueuedMessages(conversation: conv, connection: connection)
            }
        }

        let heartbeat = conversationStore.heartbeatConversation
        if !heartbeat.pendingMessages.isEmpty {
            let output = connection.output(for: Heartbeat.conversationId)
            if !output.isRunning {
                conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
            }
        }
    }
}

