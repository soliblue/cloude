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
    @State var showIntervalPicker = false
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
    @State var heartbeatEnvironmentId: UUID?
    var onShowPlans: (() -> Void)?
    var onShowMemories: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowWhiteboard: (() -> Void)?

    var isHeartbeatActive: Bool { currentPageIndex == 0 }

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
        if isHeartbeatActive {
            return conversationStore.heartbeatConversation
        } else {
            return windowManager.activeWindow?.conversation(in: conversationStore)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPageIndex) {
                heartbeatWindowContent()
                    .tag(0)

                ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                    pagedWindowContent(for: window)
                        .tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(PageSwipeDisabler())
            .onChange(of: currentPageIndex, handlePageChange)
            .onAppear {
                if let activeId = windowManager.activeWindowId,
                   let index = windowManager.windowIndex(for: activeId) {
                    currentPageIndex = index + 1
                }
            }
            .onChange(of: windowManager.activeWindowId) { _, newId in
                if let id = newId, let index = windowManager.windowIndex(for: id) {
                    if currentPageIndex != index + 1 {
                        withAnimation { currentPageIndex = index + 1 }
                    }
                }
            }
            .onTapGesture {
                if !widgetEditing && windowManager.activeWindow?.type != .terminal {
                    dismissKeyboard()
                }
            }

            inputSection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetInputActive)) { note in
            withAnimation(.easeInOut(duration: 0.15)) {
                widgetEditing = note.object as? Bool ?? false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            if widgetEditing {
                withAnimation(.easeInOut(duration: 0.15)) { widgetEditing = false }
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
        .sheet(item: $editingWindow) { _ in editWindowSheet() }
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
        .onChange(of: currentPageIndex, handleHeartbeatPageChange)
        .modifier(HeartbeatIntervalModifier(
            showIntervalPicker: $showIntervalPicker,
            conversationStore: conversationStore,
            connection: connection
        ))
    }

}
