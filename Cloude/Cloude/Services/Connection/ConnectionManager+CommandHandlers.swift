import Foundation
import Combine
import CloudeShared

extension ConnectionManager {
    func handleRenameConversation(conversationId: String, name: String) {
        if let id = UUID(uuidString: conversationId) {
            events.send(.renameConversation(conversationId: id, name: name))
        }
    }

    func handleSetConversationSymbol(conversationId: String, symbol: String?) {
        if let id = UUID(uuidString: conversationId) {
            events.send(.setConversationSymbol(conversationId: id, symbol: symbol))
        }
    }

    func handleDeleteConversation(conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            events.send(.deleteConversation(conversationId: id))
        }
    }

    func handleSwitchConversation(conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            events.send(.switchConversation(conversationId: id))
        }
    }

    func handleNotify(title: String?, body: String) {
        events.send(.notify(title: title, body: body))
    }

    func handleClipboard(_ text: String) {
        events.send(.clipboard(text))
    }

    func handleOpenURL(_ url: String) {
        events.send(.openURL(url))
    }

    func handleHaptic(_ style: String) {
        events.send(.haptic(style))
    }

    func handleSpeak(_ text: String) {
        events.send(.speak(text))
    }

    func handleQuestion(questions: [Question], conversationId: String?) {
        events.send(.question(questions: questions, conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    func handleScreenshot(conversationId: String?) {
        events.send(.screenshot(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    func handleNameSuggestion(name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            events.send(.renameConversation(conversationId: id, name: name))
            if let s = symbol {
                events.send(.setConversationSymbol(conversationId: id, symbol: s))
            }
        }
    }
}
