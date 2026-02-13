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
    @State var refreshingSessionIds: Set<String> = []

    var isHeartbeatActive: Bool { currentPageIndex == 0 }

    var currentConversation: Conversation? {
        if isHeartbeatActive {
            return conversationStore.heartbeatConversation
        } else {
            return windowManager.activeWindow?.conversationId.flatMap { conversationStore.conversation(withId: $0) }
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
            setupGitStatusHandler()
            setupFileSearchHandler()
            setupSuggestionsHandler()
            setupCostHandler()
            checkGitForAllDirectories()
            currentEffort = currentConversation?.defaultEffort
            currentModel = currentConversation?.defaultModel
            connection.onTranscription = { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBlank = trimmed.isEmpty ||
                    trimmed.contains("blank_audio") ||
                    trimmed.contains("blank audio") ||
                    trimmed.contains("silence") ||
                    trimmed.contains("no speech") ||
                    trimmed.contains("inaudible") ||
                    trimmed == "you" ||
                    trimmed == "thanks for watching"
                if !isBlank {
                    if inputText.isEmpty {
                        inputText = text
                    } else {
                        inputText += " " + text
                    }
                }
                AudioRecorder.clearPendingAudioFile()
            }
            connection.onTTSAudio = { data, messageId in
                TTSService.shared.playAudio(data, messageId: messageId)
            }
            TTSService.shared.onSynthesizeRequest = { [connection] text, messageId, voice in
                connection.synthesize(text: text, messageId: messageId, voice: voice)
            }
            connection.onUsageStats = { stats in
                usageStats = stats
                showUsageStats = true
            }
            connection.onAuthenticated = { [conversationStore, connection] in
                for conv in conversationStore.conversations where !conv.pendingMessages.isEmpty {
                    let output = connection.output(for: conv.id)
                    if !output.isRunning {
                        conversationStore.replayQueuedMessages(conversation: conv, connection: connection)
                    }
                }
                let heartbeat = conversationStore.heartbeatConversation
                if !heartbeat.pendingMessages.isEmpty {
                    let output = connection.output(for: Heartbeat.conversationId)
                    if !output.isRunning {
                        conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
                    }
                }
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
        .onReceive(connection.events) { event in
            switch event {
            case .historySync(let sessionId, _), .historySyncError(let sessionId, _):
                refreshingSessionIds.remove(sessionId)
            default: break
            }
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

    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let conversation = window.conversationId.flatMap { conversationStore.conversation(withId: $0) }

        VStack(spacing: 0) {
            windowHeader(for: window, conversation: conversation)

            switch window.type {
            case .chat:
                ConversationView(
                    connection: connection,
                    store: conversationStore,
                    conversation: conversation,
                    window: window,
                    windowManager: windowManager,
                    isCompact: false,
                    isKeyboardVisible: isKeyboardVisible,
                    onInteraction: { dismissKeyboard() },
                    onSelectRecentConversation: { conv in
                        windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    },
                    onNewConversation: {
                        let workingDir = activeWindowWorkingDirectory()
                        let newConv = conversationStore.newConversation(workingDirectory: workingDir)
                        windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    }
                )
            case .files:
                FileBrowserView(
                    connection: connection,
                    rootPath: conversation?.workingDirectory
                )
            case .gitChanges:
                GitChangesView(
                    connection: connection,
                    rootPath: conversation?.workingDirectory
                )
            }
        }
    }

    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        return HStack(spacing: 9) {
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                ConversationInfoLabel(
                    conversation: conversation,
                    showCost: true,
                    placeholderText: "Select chat..."
                )
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            Spacer()

            if let conv = conversation, conv.sessionId != nil {
                Button(action: {
                    windowManager.setActive(window.id)
                    if let newConv = conversationStore.duplicateConversation(conv) {
                        windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    }
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(7)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
            }

            Button(action: {
                windowManager.setActive(window.id)
                refreshConversation(for: window)
            }) {
                if let sid = window.conversationId.flatMap({ conversationStore.conversation(withId: $0)?.sessionId }), refreshingSessionIds.contains(sid) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 15, height: 15)
                        .padding(7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(7)
                }
            }
            .buttonStyle(.plain)
            .disabled(
                window.conversationId.map({ connection.output(for: $0).isRunning }) ?? false ||
                window.conversationId.flatMap({ conversationStore.conversation(withId: $0)?.sessionId }).map({ refreshingSessionIds.contains($0) }) ?? false
            )

            Divider()
                .frame(height: 20)

            Button(action: {
                windowManager.setActive(window.id)
                windowManager.removeWindow(window.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(Color.oceanSecondary)
    }

    private func refreshConversation(for window: ChatWindow) {
        guard let convId = window.conversationId,
              let conv = conversationStore.conversation(withId: convId),
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        refreshingSessionIds.insert(sessionId)
        let messages = conversationStore.messages(for: conv)
        if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
            conversationStore.truncateMessages(for: conv, from: lastUserIndex + 1)
        }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
    }
}

struct HeartbeatIntervalModifier: ViewModifier {
    @Binding var showIntervalPicker: Bool
    var conversationStore: ConversationStore
    var connection: ConnectionManager

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Heartbeat Interval", isPresented: $showIntervalPicker, titleVisibility: .visible) {
                ForEach(HeartbeatConfig.intervalOptions, id: \.minutes) { option in
                    Button(option.label) {
                        let value = option.minutes == 0 ? nil : option.minutes
                        conversationStore.heartbeatConfig.intervalMinutes = value
                        connection.send(.setHeartbeatInterval(minutes: value))
                    }
                }
            }
            .onAppear {
                connection.onHeartbeatConfig = { [conversationStore] intervalMinutes, unreadCount in
                    conversationStore.handleHeartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount)
                }
            }
    }
}

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(isPulsing ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .linear(duration: 0.15), value: isPulsing)
            .onChange(of: isStreaming) { _, streaming in
                withAnimation(streaming ? nil : .linear(duration: 0.15)) {
                    isPulsing = streaming
                }
            }
            .onAppear {
                if isStreaming { isPulsing = true }
            }
    }
}
