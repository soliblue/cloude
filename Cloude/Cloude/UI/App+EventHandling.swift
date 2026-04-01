import SwiftUI
import UIKit
import Combine
import CloudeShared

extension App {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .missedResponse(_, let text, _, let storedToolCalls, let interruptedConvId, let interruptedMsgId):
            let toolCalls = storedToolCalls.map { ToolCall(from: $0) }
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let convId = interruptedConvId,
               let conv = conversationStore.findConversation(withId: convId) {
                if let msgId = interruptedMsgId,
                   conv.messages.contains(where: { $0.id == msgId }) {
                    conversationStore.updateMessage(msgId, in: conv) { msg in
                        msg.text = trimmedText
                        msg.toolCalls = toolCalls
                        msg.wasInterrupted = false
                    }
                } else if !trimmedText.isEmpty,
                          !conv.messages.contains(where: { !$0.isUser && $0.text == trimmedText }) {
                    let message = ChatMessage(isUser: false, text: trimmedText, toolCalls: toolCalls)
                    conversationStore.addMessage(message, to: conv)
                }
                conversationStore.objectWillChange.send()
            } else if let conversation = windowManager.activeWindow?.conversation(in: conversationStore),
                      !trimmedText.isEmpty,
                      !conversation.messages.contains(where: { !$0.isUser && $0.text == trimmedText }) {
                let message = ChatMessage(isUser: false, text: trimmedText, toolCalls: toolCalls)
                conversationStore.addMessage(message, to: conversation)
            }

        case .streamingStarted(let convId):
            let output = connection.output(for: convId)
            if output.liveMessageId == nil, let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.resumeOrInsertLiveMessage(output: output, into: conv)
            }

        case .disconnect(let convId, let output):
            let trimmedText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasContent = !trimmedText.isEmpty || !output.toolCalls.isEmpty
            var interruptedMessageId: UUID?

            if let liveId = output.liveMessageId, let conv = conversationStore.findConversation(withId: convId) {
                if hasContent {
                    conversationStore.updateMessage(liveId, in: conv) { msg in
                        msg.text = trimmedText
                        msg.toolCalls = output.toolCalls
                        msg.wasInterrupted = true
                    }
                    interruptedMessageId = liveId
                } else {
                    conversationStore.removeMessage(liveId, from: conv)
                }
            } else if hasContent, let conv = conversationStore.findConversation(withId: convId) {
                let message = ChatMessage(
                    isUser: false,
                    text: trimmedText,
                    toolCalls: output.toolCalls,
                    wasInterrupted: true
                )
                conversationStore.addMessage(message, to: conv)
                interruptedMessageId = message.id
            }

            if let sessionId = output.newSessionId,
               let envConn = connection.connectionForConversation(convId) {
                envConn.interruptedSession = (convId, sessionId, interruptedMessageId ?? UUID())
            }

        case .memories(let sections):
            AppLogger.endInterval("memories.open", details: "sections=\(sections.count)")
            memorySections = sections
            memoriesFromCache = false
            isLoadingMemories = false
            OfflineCacheService.saveMemories(sections)

        case .plans(let stages):
            AppLogger.endInterval("plans.open", details: "stages=\(stages.count)")
            planStages = stages
            plansFromCache = false
            isLoadingPlans = false
            OfflineCacheService.savePlans(stages)

        case .defaultWorkingDirectory(let path, let environmentId):
            if showPlans && planStages.isEmpty && !isLoadingPlans {
                isLoadingPlans = true
                connection.getPlans(workingDirectory: path, environmentId: environmentId)
            }

        case .planDeleted(let stage, let filename):
            planStages[stage]?.removeAll { $0.filename == filename }

        case .renameConversation(let convId, let name):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.renameConversation(conv, to: name)
            }

        case .setConversationSymbol(let convId, let symbol):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.setConversationSymbol(conv, symbol: symbol)
            }

        case .sessionIdReceived(let convId, let sessionId):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.updateSessionId(conv, sessionId: sessionId, workingDirectory: conv.workingDirectory)
            }

        case .historySync(let sessionId, let historyMessages):
            if let conv = conversationStore.findConversation(withSessionId: sessionId) {
                let newMessages = historyMessages.map { msg in
                    return ChatMessage(
                        isUser: msg.isUser,
                        text: msg.text,
                        timestamp: msg.timestamp,
                        toolCalls: msg.toolCalls.map { ToolCall(from: $0) },
                        serverUUID: msg.serverUUID,
                        model: msg.model
                    )
                }
                conversationStore.replaceMessages(conv, with: newMessages)
                let output = connection.output(for: conv.id)
                if output.isRunning {
                    if let freshConv = conversationStore.findConversation(withId: conv.id),
                       let lastAssistant = freshConv.messages.last, !lastAssistant.isUser {
                        output.liveMessageId = lastAssistant.id
                        output.seedForReconnect(lastAssistant.text, toolCalls: lastAssistant.toolCalls)
                    } else if output.liveMessageId != nil {
                        output.liveMessageId = conversationStore.insertLiveMessage(into: conv)
                    }
                }
            }

        case .deleteConversation(let convId):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.deleteConversation(conv)
            }

        case .notify(let title, let body):
            NotificationManager.showCustomNotification(title: title, body: body)

        case .clipboard(let text):
            UIPasteboard.general.string = text

        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .haptic(let style):
            handleHaptic(style: style)

        case .switchConversation(let convId):
            if let conv = conversationStore.findConversation(withId: convId) {
                let targetId = windowManager.activeWindowId ?? windowManager.windows.first?.id
                if let targetId { windowManager.linkToCurrentConversation(targetId, conversation: conv) }
            }

        case .reconnectRunning(let convId):
            if let conv = conversationStore.findConversation(withId: convId),
               let sessionId = conv.sessionId,
               let workingDir = conv.workingDirectory, !workingDir.isEmpty {
                connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conv.environmentId)
            }

        case .question:
            break

        case .screenshot(let convId):
            handleScreenshot(conversationId: convId)

        case .whiteboard(let action, let json, let convId):
            handleWhiteboardAction(action: action, json: json, conversationId: convId)

        default:
            break
        }
    }
}
