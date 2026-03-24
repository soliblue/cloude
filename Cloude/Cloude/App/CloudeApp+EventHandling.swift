import SwiftUI
import UIKit
import Combine
import CloudeShared

extension CloudeApp {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .missedResponse(_, let text, _, let storedToolCalls, let interruptedConvId, let interruptedMsgId):
            let toolCalls = storedToolCalls.map { ToolCall(from: $0) }
            if let convId = interruptedConvId,
               let msgId = interruptedMsgId,
               let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.updateMessage(msgId, in: conv) { msg in
                    msg.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    msg.toolCalls = toolCalls
                    msg.wasInterrupted = false
                }
                conversationStore.objectWillChange.send()
            } else if let conversation = windowManager.activeWindow?.conversation(in: conversationStore) {
                let message = ChatMessage(isUser: false, text: text.trimmingCharacters(in: .whitespacesAndNewlines), toolCalls: toolCalls)
                conversationStore.addMessage(message, to: conversation)
            }

        case .streamingStarted(let convId):
            let output = connection.output(for: convId)
            if output.liveMessageId == nil, let conv = conversationStore.findConversation(withId: convId) {
                output.liveMessageId = conversationStore.insertLiveMessage(into: conv)
            }

        case .disconnect(let convId, let output):
            if let liveId = output.liveMessageId, let conv = conversationStore.findConversation(withId: convId) {
                if !output.text.isEmpty || !output.toolCalls.isEmpty {
                    conversationStore.updateMessage(liveId, in: conv) { msg in
                        msg.text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        msg.toolCalls = output.toolCalls
                        msg.wasInterrupted = true
                    }
                    if let sessionId = output.newSessionId,
                       let envConn = connection.connectionForConversation(convId) {
                        envConn.interruptedSession = (convId, sessionId, liveId)
                    }
                } else {
                    conversationStore.removeMessage(liveId, from: conv)
                }
                output.reset()
            } else if !output.text.isEmpty, let conv = conversationStore.findConversation(withId: convId) {
                let message = ChatMessage(
                    isUser: false,
                    text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    toolCalls: output.toolCalls,
                    wasInterrupted: true
                )
                conversationStore.addMessage(message, to: conv)
                if let sessionId = output.newSessionId,
                   let envConn = connection.connectionForConversation(convId) {
                    envConn.interruptedSession = (convId, sessionId, message.id)
                }
                output.reset()
            }

        case .memories(let sections):
            memorySections = sections
            memoriesFromCache = false
            isLoadingMemories = false
            OfflineCacheService.saveMemories(sections)

        case .plans(let stages):
            planStages = stages
            plansFromCache = false
            isLoadingPlans = false
            OfflineCacheService.savePlans(stages)

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
                if output.isRunning && output.liveMessageId != nil {
                    output.liveMessageId = conversationStore.insertLiveMessage(into: conv)
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
