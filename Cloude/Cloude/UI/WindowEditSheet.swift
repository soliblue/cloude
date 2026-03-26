import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
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
            ScrollView(showsIndicators: false) {
                WindowEditForm(
                    window: window,
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    connection: connection,
                    environmentStore: environmentStore,
                    onSelectConversation: onSelectConversation
                )
                .padding(.horizontal, 20)
                .padding(.top, DS.Spacing.l)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: DS.Spacing.m) {
                        Button(action: onNewConversation) {
                            Image(systemName: "plus")
                                .font(.system(size: DS.Icon.s, weight: .medium))
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
                                    .font(.system(size: DS.Icon.s, weight: .medium))
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
                                        .font(.system(size: DS.Icon.s, weight: .medium))
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
                                    .font(.system(size: DS.Icon.s, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.s)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Color.themeBackground)
    }
}
