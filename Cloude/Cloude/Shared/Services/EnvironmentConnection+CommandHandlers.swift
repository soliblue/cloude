import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleNameSuggestion(_ mgr: ConnectionManager, name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.renameConversation(conversationId: id, name: name))
            if let s = symbol {
                mgr.events.send(.setConversationSymbol(conversationId: id, symbol: s))
            }
        }
    }

}
