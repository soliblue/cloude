//
//  ChatView+Helpers.swift
//  Cloude
//

import SwiftUI

extension ChatView {
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var conversation = store.currentConversation
        if conversation == nil {
            conversation = store.newConversation()
        }

        guard let conv = conversation else { return }

        let userMessage = ChatMessage(isUser: true, text: text)
        store.addMessage(userMessage, to: conv)

        let isNewSession = conv.sessionId == nil
        connection.sendChat(text, sessionId: conv.sessionId, isNewSession: isNewSession)
        inputText = ""
    }

    func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.2)) {
            if !currentOutput.isEmpty {
                scrollProxy?.scrollTo("streaming", anchor: .bottom)
            } else if let last = messages.last {
                scrollProxy?.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    func checkClipboard() {
        hasClipboardContent = UIPasteboard.general.hasStrings
    }

    func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            inputText = text
        }
    }
}
