import SwiftUI
import UIKit
import Combine
import CloudeShared

extension App {
    func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .missedResponse(_, let text, _, let storedToolCalls, let durationMs, let costUsd, let model, let interruptedConvId, let interruptedMsgId):
            handleMissedResponse(text: text, storedToolCalls: storedToolCalls, durationMs: durationMs, costUsd: costUsd, model: model, interruptedConvId: interruptedConvId, interruptedMsgId: interruptedMsgId)
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
            handleSwitchConversation(conversationId: convId)

        case .reconnectRunning(let convId):
            handleReconnectRunning(conversationId: convId)
        case .liveSnapshot(let convId):
            handleLiveSnapshot(conversationId: convId)

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
