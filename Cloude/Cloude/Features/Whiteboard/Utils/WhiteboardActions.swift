import SwiftUI
import CloudeShared

extension App {
    func handleWhiteboardAction(action: String, json: [String: Any], conversationId: UUID?) {
        let convId = conversationId ?? windowManager.activeWindow?.conversation(in: conversationStore)?.id
        if !whiteboardStore.isPresented {
            whiteboardStore.load(conversationId: convId)
        }

        switch action {
        case "open":
            whiteboardStore.isPresented = true

        case "add":
            if let elements = json["elements"] as? [[String: Any]] {
                var decoded = elements.compactMap { el -> WhiteboardElement? in
                    if let data = try? JSONSerialization.data(withJSONObject: el) {
                        return try? JSONDecoder().decode(WhiteboardElement.self, from: data)
                    }
                    return nil
                }
                if let layout = json["layout"] as? [String: Any],
                   let layoutType = layout["type"] as? String {
                    let x = layout["x"] as? Double ?? 200
                    let y = layout["y"] as? Double ?? 200
                    let spacing = layout["spacing"] as? Double ?? 40
                    whiteboardStore.applyLayout(layoutType, to: &decoded, origin: (x, y), spacing: spacing)
                }
                whiteboardStore.resolveRelativePositions(&decoded)
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
                    type: (json["type"] as? String).flatMap { WhiteboardElementType(rawValue: $0) },
                    z: json["z"] as? Int,
                    fontSize: json["fontSize"] as? Double,
                    strokeWidth: json["strokeWidth"] as? Double,
                    strokeStyle: json["strokeStyle"] as? String,
                    opacity: json["opacity"] as? Double,
                    groupId: json["groupId"] as? String
                )
            }

        case "clear":
            whiteboardStore.clear()

        case "viewport":
            if let x = json["x"] as? Double { whiteboardStore.state.viewport.x = x }
            if let y = json["y"] as? Double { whiteboardStore.state.viewport.y = y }
            if let zoom = json["zoom"] as? Double { whiteboardStore.state.viewport.zoom = min(5.0, max(0.3, zoom)) }

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
                        conversationName: conv.name
                    )
                    connection.output(for: targetConvId).liveMessageId = conversationStore.insertLiveMessage(into: conv)
                }
            }

        case "export":
            if let uiImage = WhiteboardSheet.renderToImage(store: whiteboardStore),
               let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                let base64 = jpegData.base64EncodedString()
                let targetConvId = conversationId ?? windowManager.activeWindow?.conversation(in: conversationStore)?.id
                if let targetConvId,
                   let conv = conversationStore.findConversation(withId: targetConvId) {
                    let userMessage = ChatMessage(isUser: true, text: "[whiteboard export]", imageBase64: base64)
                    conversationStore.addMessage(userMessage, to: conv)
                    connection.sendChat(
                        "[whiteboard export]",
                        workingDirectory: conv.workingDirectory,
                        sessionId: conv.sessionId,
                        isNewSession: false,
                        conversationId: targetConvId,
                        imagesBase64: [base64],
                        conversationName: conv.name
                    )
                    connection.output(for: targetConvId).liveMessageId = conversationStore.insertLiveMessage(into: conv)
                }
            }

        default:
            break
        }
    }
}
