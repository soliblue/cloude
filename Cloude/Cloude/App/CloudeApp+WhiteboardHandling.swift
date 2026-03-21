import SwiftUI
import CloudeShared

extension CloudeApp {
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
                    stroke: json["stroke"] as? String,
                    points: json["points"] as? [[Double]],
                    closed: json["closed"] as? Bool,
                    from: json["from"] as? String,
                    to: json["to"] as? String,
                    type: (json["type"] as? String).flatMap { WhiteboardElementType(rawValue: $0) }
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
