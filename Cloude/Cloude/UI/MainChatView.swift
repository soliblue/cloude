//  MainChatView.swift

import SwiftUI
import UIKit
import Combine
import CloudeShared

struct MainChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
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
    @State var suggestions: [String] = []
    @AppStorage("enableSuggestions") var enableSuggestions = false
    @State var currentEffort: EffortLevel?
    @State var currentModel: ModelSelection?
    @State var showConversationSearch = false
    @State var showUsageStats = false
    @State var usageStats: UsageStats?
    @State var awaitingUsageStats = false
    @State var refreshingSessionIds: Set<String> = []

    var isHeartbeatActive: Bool { currentPageIndex == 0 }

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
            .onChange(of: currentPageIndex) { oldIndex, newIndex in
                if oldIndex > 0 {
                    let oldWindowIndex = oldIndex - 1
                    if oldWindowIndex < windowManager.windows.count {
                        let oldWindow = windowManager.windows[oldWindowIndex]
                        if let convId = oldWindow.conversationId,
                           let conv = conversationStore.conversation(withId: convId),
                           conv.isEmpty {
                            conversationStore.deleteConversation(conv)
                            windowManager.removeWindow(oldWindow.id)
                        }
                    }
                }
                if newIndex > 0 {
                    windowManager.navigateToWindow(at: newIndex - 1)
                }
            }
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
                dismissKeyboard()
            }

            VStack(spacing: 0) {
                GlobalInputBar(
                    inputText: $inputText,
                    attachedImages: $attachedImages,
                    attachedFiles: $attachedFiles,
                    suggestions: $suggestions,
                    isConnected: connection.isAuthenticated,
                    isWhisperReady: connection.isWhisperReady,
                    isTranscribing: connection.isTranscribing,
                    isRunning: activeConversationIsRunning,
                    skills: connection.skills,
                    fileSearchResults: fileSearchResults,
                    conversationDefaultEffort: currentConversation?.defaultEffort,
                    conversationDefaultModel: currentConversation?.defaultModel,
                    onSend: sendMessage,
                    onStop: stopActiveConversation,
                    onTranscribe: transcribeAudio,
                    onFileSearch: searchFiles,
                    currentEffort: $currentEffort,
                    currentModel: $currentModel
                )

                pageIndicator()
                    .frame(height: 44)
                    .padding(.bottom, isKeyboardVisible ? 12 : 4)
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .background(Color.oceanBackground)
        }
        .onAppear {
            initializeFirstWindow()
            checkGitForAllDirectories()
            currentEffort = currentConversation?.defaultEffort
            currentModel = currentConversation?.defaultModel
            TTSService.shared.onSynthesizeRequest = { [connection] text, messageId, voice in
                connection.synthesize(text: text, messageId: messageId, voice: voice)
            }
        }
        .onChange(of: windowManager.activeWindowId) { oldId, newId in
            if let oldId = oldId {
                drafts[oldId] = (inputText, attachedImages, currentEffort, currentModel)
                cleanupEmptyConversation(for: oldId)
            }
            suggestions = []
            if let newId = newId, let draft = drafts[newId] {
                inputText = draft.text
                attachedImages = draft.images
                currentEffort = draft.effort
                currentModel = draft.model
            } else {
                inputText = ""
                attachedImages = []
                currentEffort = currentConversation?.defaultEffort
                currentModel = currentConversation?.defaultModel
            }
            if windowManager.windows.count == 1 { syncActiveWindowToStore() }
        }
        .onChange(of: conversationStore.currentConversation?.id) { _, _ in
            if windowManager.windows.count == 1 { updateActiveWindowLink() }
        }
        .sheet(item: $editingWindow) { window in
            WindowEditSheet(
                window: window,
                conversationStore: conversationStore,
                windowManager: windowManager,
                connection: connection,
                onSelectConversation: { conv in
                    if let oldConvId = window.conversationId,
                       let oldConv = conversationStore.conversation(withId: oldConvId),
                       oldConv.isEmpty, oldConv.id != conv.id {
                        conversationStore.deleteConversation(oldConv)
                    }
                    windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    editingWindow = nil
                },
                onNewConversation: {
                    if let oldConvId = window.conversationId,
                       let oldConv = conversationStore.conversation(withId: oldConvId),
                       oldConv.isEmpty {
                        conversationStore.deleteConversation(oldConv)
                    }
                    let workingDir = activeWindowWorkingDirectory()
                    let newConv = conversationStore.newConversation(workingDirectory: workingDir)
                    windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    editingWindow = nil
                },
                onDismiss: { editingWindow = nil },
                onRefresh: {
                    guard let convId = window.conversationId,
                          let conv = conversationStore.conversation(withId: convId),
                          let sessionId = conv.sessionId,
                          let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
                    connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                },
                onDuplicate: { newConv in
                    windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    editingWindow = nil
                }
            )
        }
        .sheet(isPresented: $showConversationSearch) {
            ConversationSearchSheet(
                conversationStore: conversationStore,
                windowManager: windowManager,
                onSelect: { conv in
                    showConversationSearch = false
                    if let activeWindow = windowManager.activeWindow {
                        if let oldConvId = activeWindow.conversationId,
                           let oldConv = conversationStore.conversation(withId: oldConvId),
                           oldConv.isEmpty, oldConv.id != conv.id {
                            conversationStore.deleteConversation(oldConv)
                        }
                        windowManager.linkToCurrentConversation(activeWindow.id, conversation: conv)
                    }
                }
            )
        }
        .sheet(isPresented: $showUsageStats) {
            if let stats = usageStats {
                UsageStatsSheet(stats: stats)
            } else {
                ProgressView("Loading usage stats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.oceanBackground)
            }
        }
        .onReceive(connection.events, perform: handleConnectionEvent)
        // Fallback: a PassthroughSubject can be missed if this view isn't mounted yet.
        .onChange(of: connection.isAuthenticated) { _, authed in
            guard authed else { return }
            replayQueuedMessagesIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            fetchLatestScreenshot()
        }
        .onChange(of: currentPageIndex) { oldIndex, newIndex in
            if oldIndex == 0 && newIndex != 0 {
                connection.send(.markHeartbeatRead)
                conversationStore.markHeartbeatRead()
            }
            if newIndex > 0 {
                let windowIndex = newIndex - 1
                if windowIndex < windowManager.windows.count {
                    windowManager.markRead(windowManager.windows[windowIndex].id)
                }
            }
            suggestions = []
        }
        .onChange(of: connection.agentState) { oldState, newState in
            if oldState != .idle && newState == .idle && !isHeartbeatActive && enableSuggestions {
                requestSuggestions()
            }
        }
        .modifier(HeartbeatIntervalModifier(
            showIntervalPicker: $showIntervalPicker,
            conversationStore: conversationStore,
            connection: connection
        ))
    }
}
