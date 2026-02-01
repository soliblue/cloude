//
//  WindowEditSheet.swift
//  Cloude

import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void
    let onShowAllConversations: () -> Void
    let onNewConversation: () -> Void
    let onDismiss: () -> Void
    var onRefresh: (() async -> Void)?

    var body: some View {
        NavigationStack {
            WindowEditForm(
                window: window,
                projectStore: projectStore,
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
                onRefresh: onRefresh
            )
            .padding(.horizontal, 20)
            .navigationTitle("Edit Chat")
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
            .background(.ultraThinMaterial)
            .scrollContentBackground(.hidden)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.height(480)])
        .presentationBackground(.ultraThinMaterial)
    }
}
