import SwiftUI
import UIKit
import Combine
import CloudeShared

extension CloudeApp {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .missedResponse(_, let text, _, let storedToolCalls, let interruptedConvId, let interruptedMsgId):
            let toolCalls = storedToolCalls.map {
                var tc = ToolCall(
                    name: $0.name,
                    input: $0.input,
                    toolId: $0.toolId,
                    parentToolId: $0.parentToolId,
                    textPosition: $0.textPosition
                )
                tc.resultOutput = $0.resultContent
                return tc
            }
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

        case .disconnect(let convId, let output):
            if output.text.isEmpty { return }
            if let conv = conversationStore.findConversation(withId: convId) {
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
                    let toolCalls = msg.toolCalls.map {
                        var tc = ToolCall(
                            name: $0.name,
                            input: $0.input,
                            toolId: $0.toolId,
                            parentToolId: $0.parentToolId,
                            textPosition: $0.textPosition,
                            editInfo: $0.editInfo
                        )
                        tc.resultOutput = $0.resultContent
                        return tc
                    }
                    return ChatMessage(
                        isUser: msg.isUser,
                        text: msg.text,
                        timestamp: msg.timestamp,
                        toolCalls: toolCalls,
                        serverUUID: msg.serverUUID,
                        model: msg.model
                    )
                }
                conversationStore.replaceMessages(conv, with: newMessages)
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
            let generator: UIImpactFeedbackGenerator
            switch style {
            case "light": generator = UIImpactFeedbackGenerator(style: .light)
            case "heavy": generator = UIImpactFeedbackGenerator(style: .heavy)
            case "rigid": generator = UIImpactFeedbackGenerator(style: .rigid)
            case "soft": generator = UIImpactFeedbackGenerator(style: .soft)
            default: generator = UIImpactFeedbackGenerator(style: .medium)
            }
            generator.impactOccurred()

        case .switchConversation(let convId):
            if let conv = conversationStore.findConversation(withId: convId) {
                let targetId = windowManager.activeWindowId ?? windowManager.windows.first?.id
                if let targetId { windowManager.linkToCurrentConversation(targetId, conversation: conv) }
            }

        case .question:
            break

        case .screenshot(let convId):
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {

                    let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                    let image = renderer.image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }

                    if let jpegData = image.jpegData(compressionQuality: 0.7) {
                        let base64 = jpegData.base64EncodedString()

                        let targetConvId = convId ?? windowManager.activeWindow?.conversation(in: conversationStore)?.id
                        if let targetConvId,
                           let conv = conversationStore.findConversation(withId: targetConvId) {

                            let userMessage = ChatMessage(isUser: true, text: "[screenshot]", imageBase64: base64)
                            conversationStore.addMessage(userMessage, to: conv)

                            connection.sendChat(
                                "[screenshot]",
                                workingDirectory: conv.workingDirectory,
                                sessionId: conv.sessionId,
                                isNewSession: false,
                                conversationId: targetConvId,
                                imagesBase64: [base64],
                                conversationName: conv.name,
                                conversationSymbol: conv.symbol
                            )
                        }
                    }
                }
            }

        case .whiteboard(let action, let json, let convId):
            handleWhiteboardAction(action: action, json: json, conversationId: convId)

        default:
            break
        }
    }

    func handleWhiteboardAction(action: String, json: [String: Any], conversationId: UUID?) {
        let convId = conversationId ?? windowManager.activeWindow?.conversation(in: conversationStore)?.id
        if !showWhiteboard {
            whiteboardStore.load(conversationId: convId)
            showWhiteboard = true
        }

        switch action {
        case "add":
            if let elements = json["elements"] as? [[String: Any]] {
                let decoded = elements.compactMap { el -> WhiteboardElement? in
                    if let data = try? JSONSerialization.data(withJSONObject: el) {
                        return try? JSONDecoder().decode(WhiteboardElement.self, from: data)
                    }
                    return nil
                }
                whiteboardStore.addElements(decoded)
            }

        case "remove":
            if let ids = json["ids"] as? [String] {
                whiteboardStore.removeElements(ids: ids)
            }

        case "update":
            if let id = json["id"] as? String {
                whiteboardStore.updateElement(
                    id: id,
                    x: json["x"] as? Double,
                    y: json["y"] as? Double,
                    w: json["w"] as? Double,
                    h: json["h"] as? Double,
                    label: json["label"] as? String,
                    fill: json["fill"] as? String,
                    stroke: json["stroke"] as? String
                )
            }

        case "clear":
            whiteboardStore.clear()

        case "snapshot":
            if let data = try? JSONEncoder().encode(whiteboardStore.state),
               let jsonString = String(data: data, encoding: .utf8) {

                let targetConvId = conversationId ?? windowManager.activeWindow?.conversation(in: conversationStore)?.id
                if let targetConvId,
                   let conv = conversationStore.findConversation(withId: targetConvId) {

                    let userMessage = ChatMessage(isUser: true, text: "[whiteboard snapshot]\n\(jsonString)")
                    conversationStore.addMessage(userMessage, to: conv)

                    connection.sendChat(
                        "[whiteboard snapshot]\n\(jsonString)",
                        workingDirectory: conv.workingDirectory,
                        sessionId: conv.sessionId,
                        isNewSession: false,
                        conversationId: targetConvId,
                        conversationName: conv.name,
                        conversationSymbol: conv.symbol
                    )
                }
            }

        default:
            break
        }
    }
}
