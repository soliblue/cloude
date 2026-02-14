import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void
    let onNewConversation: () -> Void
    let onDismiss: () -> Void
    var onRefresh: (() async -> Void)?
    var onDuplicate: ((Conversation) -> Void)?

    @State private var isRefreshing = false

    private var conversation: Conversation? {
        window.conversation(in: conversationStore)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                WindowEditForm(
                    window: window,
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    connection: connection,
                    onSelectConversation: onSelectConversation
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
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: onNewConversation) {
                            Image(systemName: "plus")
                        }

                        if let conv = conversation, conv.sessionId != nil {
                            Divider()
                                .frame(height: 20)

                            Button {
                                if let newConv = conversationStore.duplicateConversation(conv) {
                                    onDuplicate?(newConv)
                                }
                            } label: {
                                Image(systemName: "arrow.triangle.branch")
                            }
                        }

                        if onRefresh != nil {
                            Divider()
                                .frame(height: 20)

                            Button {
                                guard !isRefreshing else { return }
                                isRefreshing = true
                                Task {
                                    await onRefresh?()
                                    isRefreshing = false
                                }
                            } label: {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .disabled(isRefreshing || connection.isAnyRunning)
                        }

                        if windowManager.canRemoveWindow {
                            Divider()
                                .frame(height: 20)

                            Button {
                                windowManager.removeWindow(window.id)
                                onDismiss()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Color.oceanBackground)
    }
}
