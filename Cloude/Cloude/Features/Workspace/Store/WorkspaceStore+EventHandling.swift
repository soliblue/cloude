import Foundation
import CloudeShared

extension WorkspaceStore {
    func handleConnectionEvent(_ event: ConnectionEvent, connection: ConnectionManager, conversationStore: ConversationStore) {
        switch event {
        case .historySync(let sessionId, _), .historySyncError(let sessionId, _):
            AppLogger.endInterval("conversation.refresh", key: conversationStore.findConversation(withSessionId: sessionId)?.id.uuidString, details: "sessionId=\(sessionId)")
            refreshingSessionIds.remove(sessionId)
        case .authenticated:
            replayQueuedMessagesIfNeeded(connection: connection, conversationStore: conversationStore)
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
                inputText = inputText.isEmpty ? text : inputText + " " + text
            }
            AudioRecorder.clearPendingAudioFile()
        case .usageStats(let stats):
            if awaitingUsageStats {
                AppLogger.endInterval("usage.open", details: "dataPoints=\(stats.dailyActivity.count)")
                awaitingUsageStats = false
                usageStats = stats
                showUsageStats = true
            }
        case .fileSearchResults(let files, _):
            fileSearchResults = files
        case .gitStatus(let path, let status, _):
            if gitBranches[path] == nil, !status.branch.isEmpty {
                gitBranches[path] = status.branch
            }
            let adds = status.files.compactMap(\.additions).reduce(0, +)
            let dels = status.files.compactMap(\.deletions).reduce(0, +)
            gitStats[path] = (adds, dels)
            if let idx = pendingGitChecks.firstIndex(where: { $0.path == path }) {
                pendingGitChecks.remove(at: idx)
            }
            checkNextGitDirectory(connection: connection)
        case .turnCompleted(let convId):
            if let conv = conversationStore.conversation(withId: convId),
               let dir = conv.workingDirectory,
               !dir.isEmpty {
                connection.gitStatus(path: dir, environmentId: conv.environmentId)
            }
        case .lastAssistantMessageCostUpdate(let convId, let costUsd):
            if let conversation = conversationStore.conversation(withId: convId),
               let lastAssistantMsg = conversation.messages.last(where: { !$0.isUser }) {
                conversationStore.updateMessage(lastAssistantMsg.id, in: conversation) { msg in
                    msg.costUsd = costUsd
                }
                conversationStore.mutate(convId) { conv in
                    let computed = conv.messages.compactMap(\.costUsd).reduce(0, +)
                    conv.savedTotalCost = max(computed, conv.savedTotalCost ?? 0)
                }
            }
        default:
            break
        }
    }

    func replayQueuedMessagesIfNeeded(connection: ConnectionManager, conversationStore: ConversationStore) {
        for conv in conversationStore.conversations where !conv.pendingMessages.isEmpty {
            if !connection.output(for: conv.id).isRunning {
                conversationStore.replayQueuedMessages(conversation: conv, connection: connection)
            }
        }
    }
}
