//  MainChatView.swift

import SwiftUI
import UIKit
import Combine
import CloudeShared

struct MainChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var environmentStore: EnvironmentStore
    @State var editingWindow: ChatWindow?
    @State var currentPageIndex: Int = 0
    @State var isKeyboardVisible = false
    @State var inputText = ""
    @State var attachedImages: [AttachedImage] = []
    @State var attachedFiles: [AttachedFile] = []
    @State var drafts: [UUID: (text: String, images: [AttachedImage], effort: EffortLevel?, model: ModelSelection?)] = [:]
    @State var gitBranches: [String: String] = [:]
    @State var pendingGitChecks: [String] = []
    @State var fileSearchResults: [String] = []
    @State var currentEffort: EffortLevel?
    @State var currentModel: ModelSelection?
    @State var showConversationSearch = false
    @State var showUsageStats = false
    @State var widgetEditing = false
    @State var usageStats: UsageStats?
    @State var awaitingUsageStats = false
    @State var refreshingSessionIds: Set<String> = []
    @State var refreshTrigger = false
    @State var exportCopied = false
    var onShowPlans: (() -> Void)?
    var onShowMemories: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowWhiteboard: (() -> Void)?

    var hasEnvironmentMismatch: Bool {
        if let envId = currentConversation?.environmentId {
            return !(connection.connection(for: envId)?.isAuthenticated ?? false)
        }
        return false
    }

    var activeEnvConnection: EnvironmentConnection? {
        let envId = currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
        return connection.connection(for: envId)
    }

    var currentConversation: Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("MainChat", "render")
        #endif
        VStack(spacing: 0) {
            TabView(selection: $currentPageIndex) {
                ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                    pagedWindowContent(for: window)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(PageSwipeDisabler())
            .onChange(of: currentPageIndex, handlePageChange)
            .onAppear {
                if let activeId = windowManager.activeWindowId,
                   let index = windowManager.windowIndex(for: activeId) {
                    currentPageIndex = index
                }
            }
            .onChange(of: windowManager.activeWindowId) { _, newId in
                if let id = newId, let index = windowManager.windowIndex(for: id) {
                    if currentPageIndex != index {
                        withAnimation { currentPageIndex = index }
                    }
                }
            }
            .onTapGesture {
                if !widgetEditing {
                    dismissKeyboard()
                }
            }

            inputSection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetInputActive)) { note in
            withAnimation(.easeInOut(duration: DS.Duration.quick)) {
                widgetEditing = note.object as? Bool ?? false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            if widgetEditing {
                withAnimation(.easeInOut(duration: DS.Duration.quick)) { widgetEditing = false }
            }
        }
        .onAppear {
            initializeFirstWindow()
            checkGitForAllDirectories()
            currentEffort = currentConversation?.defaultEffort
            currentModel = currentConversation?.defaultModel
        }
        .onChange(of: windowManager.activeWindowId, handleActiveWindowChange)
        .onChange(of: currentModel, handleModelChange)
        .onChange(of: currentEffort, handleEffortChange)
        .sheet(item: $editingWindow) { window in editWindowSheet(window) }
        .sheet(isPresented: $showConversationSearch) { conversationSearchSheetContent() }
        .sheet(isPresented: $showUsageStats) { usageStatsSheetContent() }
        .onReceive(NotificationCenter.default.publisher(for: .editActiveWindow)) { _ in
            if let window = windowManager.activeWindow {
                editingWindow = window
            }
        }
        .onReceive(connection.events, perform: handleConnectionEvent)
        .onChange(of: connection.isAuthenticated) { _, authed in
            guard authed else { return }
            replayQueuedMessagesIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            withAnimation(keyboardAnimation(from: notification)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            withAnimation(keyboardAnimation(from: notification)) { isKeyboardVisible = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            fetchLatestScreenshot()
        }
    }

}
