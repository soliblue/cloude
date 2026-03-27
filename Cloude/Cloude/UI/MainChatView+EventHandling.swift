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

        case .usageStats(let stats):
            guard awaitingUsageStats else { break }
            awaitingUsageStats = false
            usageStats = stats
            showUsageStats = true

        case .fileSearchResults(let files, _):
            fileSearchResults = files

        case .gitStatus(let path, let status, _):
            if gitBranches[path] == nil, !status.branch.isEmpty {
                gitBranches[path] = status.branch
            }
            let adds = status.files.compactMap(\.additions).reduce(0, +)
            let dels = status.files.compactMap(\.deletions).reduce(0, +)
            gitStats[path] = (adds, dels)
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
    }
}

