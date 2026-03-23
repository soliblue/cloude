// EnvironmentConnection+IOSTools.swift

import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleIOSToolCall(_ mgr: ConnectionManager, name: String, input: String?, conversationId: String?) {
        let action = String(name.dropFirst("mcp__ios__".count))
        let json = input.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

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
        case "skip":
            mgr.events.send(.heartbeatSkipped(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
        case "screenshot":
            mgr.events.send(.screenshot(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
        case "whiteboard_open", "whiteboard_add", "whiteboard_remove", "whiteboard_update", "whiteboard_clear", "whiteboard_snapshot", "whiteboard_viewport", "whiteboard_export":
            let wbAction = String(action.dropFirst("whiteboard_".count))
            mgr.events.send(.whiteboard(action: wbAction, json: json, conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
        default:
            break
        }
    }
}
