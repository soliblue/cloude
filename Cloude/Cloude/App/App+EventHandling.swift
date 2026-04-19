import SwiftUI
import UIKit
import CloudeShared

extension App {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .disconnect(let convId, let output):
            handleDisconnect(conversationId: convId, output: output)
        case .renameConversation(let convId, let name):
            handleRenameConversation(conversationId: convId, name: name)
        case .setConversationSymbol(let convId, let symbol):
            handleSetConversationSymbol(conversationId: convId, symbol: symbol)
        case .sessionIdReceived(let convId, let sessionId):
            handleSessionIdReceived(conversationId: convId, sessionId: sessionId)
        case .turnCompleted(let convId):
            handleTurnCompleted(conversationId: convId)
        case .historySync(let sessionId, let historyMessages):
            handleHistorySync(sessionId: sessionId, historyMessages: historyMessages)
        case .deleteConversation(let convId):
            handleDeleteConversation(conversationId: convId)

        case .notify(let title, let body):
            NotificationManager.showNotification(title: title, body: body)

        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .haptic(let style):
            handleHaptic(style: style)

        case .switchConversation(let convId):
            handleSwitchConversation(conversationId: convId)

        case .liveSnapshot(let convId):
            handleLiveSnapshot(conversationId: convId)

        case .resumeBegin(let convId, let messageId):
            handleResumeBegin(conversationId: convId, messageId: messageId)

        default:
            break
        }
    }
}
