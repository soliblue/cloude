import SwiftUI
import UIKit
import Combine
import CloudeShared

struct WorkspaceView: View {
    @StateObject var store = WorkspaceStore()
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var environmentStore: EnvironmentStore
    @Environment(\.appTheme) var appTheme
    var onShowSettings: (() -> Void)?
    let onSendMessage: () -> Void
    let onStopActiveConversation: () -> Void
    let onRefreshConversation: (Window) -> Void
    let onSelectConversationForEditing: (Window, Conversation) -> Void
    let onRefreshEditingWindowConversation: (Window) async -> Void
    let onDuplicateEditingConversation: (Window, Conversation) -> Void
    let onSelectConversationFromSearch: (Conversation) -> Void

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("MainChat", "render")
        #endif
        VStack(spacing: 0) {
            TabView(selection: activeWindowIdBinding) {
                ForEach(windowManager.windows) { window in
                    pagedWindowContent(for: window)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(window.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onTapGesture {
                dismissKeyboard()
            }
            .overlay(alignment: .trailing) {
                if !isKeyboardVisible && !(windowManager.activeWindow?.conversation(in: conversationStore)?.messages.isEmpty ?? true) {
                    WindowCreateButton {
                        if windowManager.windows.count >= 5, let id = windowManager.activeWindowId {
                            windowManager.removeWindow(id)
                        }
                        windowManager.addWindowWithNewChat(
                            conversationStore: conversationStore,
                            environmentStore: environmentStore
                        )
                    }
                    .transition(.opacity.animation(.easeIn(duration: DS.Duration.m)))
                }
            }
            windowSwitcher()
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, isKeyboardVisible ? DS.Spacing.m : DS.Spacing.xs)
                .background(
                    Color.themeBackground
                        .ignoresSafeArea(.container, edges: .bottom)
                        .ignoresSafeArea(.keyboard)
                )
        }
        .onAppear {
            windowManager.initializeFirstWindow(
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
            if let activeId = windowManager.activeWindowId {
                windowManager.checkGitForActiveWindow(
                    windowId: activeId,
                    conversationStore: conversationStore,
                    environmentStore: environmentStore
                )
            }
        }
        .onChange(of: windowManager.activeWindowId) { oldValue, newValue in
            windowManager.handleActiveWindowChange(
                oldId: oldValue,
                newId: newValue,
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
        }
        .sheet(item: windowBeingEditedBinding) { window in editWindowSheet(window) }
        .sheet(isPresented: isShowingConversationSearchBinding) { conversationSearchSheetContent() }
        .onReceive(NotificationCenter.default.publisher(for: .editActiveWindow)) { _ in
            if let window = windowManager.activeWindow { store.windowBeingEdited = window }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openConversationSearch)) { _ in
            store.isShowingConversationSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissWorkspaceTransientUI)) { _ in
            store.windowBeingEdited = nil
            store.isShowingConversationSearch = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            store.isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            store.isKeyboardVisible = false
        }
    }

}
