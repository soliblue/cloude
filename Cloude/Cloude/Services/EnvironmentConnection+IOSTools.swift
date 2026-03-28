// EnvironmentConnection+IOSTools.swift

import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleIOSToolCall(_ mgr: ConnectionManager, name: String, input: String?, conversationId: String?) {
        let action = String(name.dropFirst("mcp__ios__".count))
        let json = toolInputJSON(input)

        switch action {
        case "rename":
            if let convId = conversationId, let id = UUID(uuidString: convId), let n = json["name"] as? String {
                mgr.events.send(.renameConversation(conversationId: id, name: n))
            }
        case "symbol":
            if let convId = conversationId, let id = UUID(uuidString: convId) {
                mgr.events.send(.setConversationSymbol(conversationId: id, symbol: json["symbol"] as? String))
            }
        case "notify":
            if let body = json["message"] as? String {
                mgr.events.send(.notify(title: nil, body: body))
            }
        case "clipboard":
            if let text = json["text"] as? String {
                mgr.events.send(.clipboard(text))
            }
        case "open":
            if let url = json["url"] as? String {
                mgr.events.send(.openURL(url))
            }
        case "haptic":
            mgr.events.send(.haptic(json["style"] as? String ?? "medium"))
        case "switch":
            if let id = json["conversationId"] as? String, let uuid = UUID(uuidString: id) {
                mgr.events.send(.switchConversation(conversationId: uuid))
            }
        case "delete":
            if let convId = conversationId, let id = UUID(uuidString: convId) {
                mgr.events.send(.deleteConversation(conversationId: id))
            }
        case "screenshot":
            mgr.events.send(.screenshot(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
        default:
            break
        }
    }

    func handleWhiteboardToolCall(_ mgr: ConnectionManager, name: String, input: String?, conversationId: String?) {
        let action = String(name.dropFirst("mcp__whiteboard__".count))
        let json = toolInputJSON(input)
        mgr.events.send(.whiteboard(action: action, json: json, conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    private func toolInputJSON(_ input: String?) -> [String: Any] {
        input
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }
}
