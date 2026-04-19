import SwiftUI
import UIKit
import Combine
import CloudeShared

struct WorkspaceView: View {
    @StateObject var store = WorkspaceStore()
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var environmentStore: EnvironmentStore
    @Environment(\.appTheme) var appTheme
    var onShowSettings: (() -> Void)?
    var onShowWhiteboard: (() -> Void)?

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
                if !isKeyboardVisible && !(currentConversation?.messages.isEmpty ?? true) {
                    WindowCreateButton {
                        if windowManager.windows.count >= 5, let id = windowManager.activeWindowId {
                            windowManager.removeWindow(id)
                        }
                        store.addWindowWithNewChat(
                            conversationStore: conversationStore,
                            windowManager: windowManager,
                            environmentStore: environmentStore
                        )
                    }
                    .transition(.opacity.animation(.easeIn(duration: DS.Duration.m)))
                }
            }

            inputSection()
        }
        .onAppear {
            store.initializeFirstWindow(conversationStore: conversationStore, windowManager: windowManager)
            store.currentEffort = currentConversation?.defaultEffort
            store.currentModel = currentConversation?.defaultModel
        }
        .task(id: connection.isAnyAuthenticated) {
            guard connection.isAnyAuthenticated else { return }
            try? await Task.sleep(for: .seconds(4))
            store.checkGitForAllDirectories(conversationStore: conversationStore)
            store.checkNextGitDirectory(connection: connection)
        }
        .onChange(of: windowManager.activeWindowId) { oldValue, newValue in
            store.handleActiveWindowChange(oldId: oldValue, newId: newValue, conversationStore: conversationStore, windowManager: windowManager, connection: connection)
        }
        .onChange(of: currentModel) { _, newValue in
            store.handleModelChange(newValue, conversationStore: conversationStore, windowManager: windowManager)
        }
        .onChange(of: currentEffort) { _, newValue in
            store.handleEffortChange(newValue, conversationStore: conversationStore, windowManager: windowManager)
        }
        .sheet(item: editingWindowBinding) { window in editWindowSheet(window) }
        .sheet(isPresented: showConversationSearchBinding) { conversationSearchSheetContent() }
        .onReceive(NotificationCenter.default.publisher(for: .editActiveWindow)) { _ in
            if let window = windowManager.activeWindow { store.editingWindow = window }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openConversationSearch)) { _ in
            store.openConversationSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissWorkspaceTransientUI)) { _ in
            store.dismissTransientUI()
        }
        .onReceive(connection.events) { event in
            store.handleConnectionEvent(event, connection: connection, conversationStore: conversationStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            store.isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            store.isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            store.fetchLatestScreenshot()
        }
    }

}
