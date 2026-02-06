//
//  WindowEditSheet.swift
//  Cloude

import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void
    let onShowAllConversations: () -> Void
    let onNewConversation: () -> Void
    let onDismiss: () -> Void
    var onRefresh: (() async -> Void)?
    var onDuplicate: ((Conversation) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                WindowEditForm(
                    window: window,
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    connection: connection,
                    onSelectConversation: onSelectConversation,
                    onShowAllConversations: onShowAllConversations,
                    onNewConversation: onNewConversation,
                    showRemoveButton: true,
                    onRemove: {
                        windowManager.removeWindow(window.id)
                        onDismiss()
                    },
                    onRefresh: onRefresh,
                    onDuplicate: onDuplicate
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }
}
