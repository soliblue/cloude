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
    var onShowPlans: (() -> Void)?
    var onShowMemories: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowWhiteboard: (() -> Void)?

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("MainChat", "render")
        #endif
        VStack(spacing: 0) {
            ZStack {
                ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                    let isActive = currentPageIndex == index
                    windowPage(for: window, isActive: isActive)
                }
            }
            .onChange(of: currentPageIndex) { oldValue, newValue in
                store.handlePageChange(oldIndex: oldValue, newIndex: newValue, conversationStore: conversationStore, windowManager: windowManager)
            }
            .onAppear {
                if let activeId = windowManager.activeWindowId,
                   let index = windowManager.windowIndex(for: activeId) {
                    currentPageIndex = index
                }
            }
            .onChange(of: windowManager.activeWindowId) { _, newId in
                if let id = newId, let index = windowManager.windowIndex(for: id) {
                    if currentPageIndex != index {
                        currentPageIndex = index
                    }
                }
            }
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
                .zIndex(1)
        }
        .onAppear {
            store.initializeFirstWindow(conversationStore: conversationStore, windowManager: windowManager)
            store.currentEffort = currentConversation?.defaultEffort
            store.currentModel = currentConversation?.defaultModel
        }
        .task(id: connection.isAuthenticated) {
            guard connection.isAuthenticated else { return }
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
        .sheet(isPresented: showUsageStatsBinding) { usageStatsSheetContent() }
        .onReceive(NotificationCenter.default.publisher(for: .editActiveWindow)) { _ in
            store.beginEditingActiveWindow(windowManager: windowManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openConversationSearch)) { _ in
            store.openConversationSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestUsageStats)) { _ in
            store.requestUsageStats(
                connection: connection,
                environmentStore: environmentStore,
                conversationStore: conversationStore,
                windowManager: windowManager
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissWorkspaceTransientUI)) { _ in
            store.dismissTransientUI()
        }
        .onReceive(connection.events) { event in
            store.handleConnectionEvent(event, connection: connection, conversationStore: conversationStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            withAnimation(keyboardAnimation(from: notification)) { store.setKeyboardVisible(true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            withAnimation(keyboardAnimation(from: notification)) { store.setKeyboardVisible(false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            store.fetchLatestScreenshot()
        }
    }

}
