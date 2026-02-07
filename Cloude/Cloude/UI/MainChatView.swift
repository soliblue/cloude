//  MainChatView.swift

import SwiftUI
import UIKit
import Photos
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
    @State var drafts: [UUID: (text: String, images: [AttachedImage])] = [:]
    @State var gitBranches: [String: String] = [:]
    @State var pendingGitChecks: [String] = []
    @State var showIntervalPicker = false
    @State var fileSearchResults: [String] = []
    @State var autocompleteSuggestion: String = ""
    @State var currentEffort: EffortLevel?
    @State var currentModel: ModelSelection?

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
                    autocompleteSuggestion: $autocompleteSuggestion,
                    isConnected: connection.isAuthenticated,
                    isWhisperReady: connection.isWhisperReady,
                    isTranscribing: connection.isTranscribing,
                    isRunning: activeConversationIsRunning,
                    skills: connection.skills,
                    fileSearchResults: fileSearchResults,
                    conversationDefaultEffort: currentConversation?.defaultEffort,
                    conversationDefaultModel: currentConversation?.defaultModel,
                    onSend: sendMessage,
                    onEffortChange: { currentEffort = $0 },
                    onModelChange: { currentModel = $0 },
                    onStop: stopActiveConversation,
                    onTranscribe: transcribeAudio,
                    onFileSearch: searchFiles,
                    onAutocomplete: requestAutocomplete
                )

                pageIndicator()
                    .frame(height: 44)
                    .padding(.bottom, isKeyboardVisible ? 12 : 4)
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .background(AnyShapeStyle(.ultraThinMaterial))
        }
        .onAppear {
            initializeFirstWindow()
            setupGitStatusHandler()
            setupFileSearchHandler()
            setupAutocompleteHandler()
            setupCostHandler()
            checkGitForAllDirectories()
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
        }
        .onChange(of: windowManager.activeWindowId) { oldId, newId in
            if let oldId = oldId {
                if !inputText.isEmpty || !attachedImages.isEmpty {
                    drafts[oldId] = (inputText, attachedImages)
                } else {
                    drafts.removeValue(forKey: oldId)
                }
                cleanupEmptyConversation(for: oldId)
            }
            autocompleteSuggestion = ""
            if let newId = newId, let draft = drafts[newId] {
                inputText = draft.text
                attachedImages = draft.images
            } else {
                inputText = ""
                attachedImages = []
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
        let workingDir = conversation?.workingDirectory ?? ""
        let gitBranch = workingDir.nilIfEmpty.flatMap { gitBranches[$0] }
        let availableTypes = WindowType.allCases.filter { type in
            if type == .gitChanges { return gitBranch != nil }
            return true
        }
        let conversationId = window.conversationId
        let isStreaming = conversationId.map { connection.output(for: $0).isRunning } ?? false

        return HStack(spacing: 9) {
            ForEach(availableTypes, id: \.self) { type in
                Button(action: {
                    windowManager.setActive(window.id)
                    windowManager.setWindowType(window.id, type: type)
                }) {
                    Image(systemName: type.icon)
                        .font(.system(size: 17))
                        .foregroundColor(window.type == type ? .accentColor : .secondary)
                        .opacity(window.type == type && isStreaming ? 0.4 : 1.0)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                HStack(spacing: 5) {
                    Image.safeSymbol(conversation?.symbol)
                        .font(.system(size: 15))
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                        Text("• \(folder)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let conv = conversation, conv.totalCost > 0 {
                        Text("• $\(String(format: "%.2f", conv.totalCost))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

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
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.oceanSecondary)
    }
}

struct HeartbeatIntervalModifier: ViewModifier {
    @Binding var showIntervalPicker: Bool
    var conversationStore: ConversationStore
    var connection: ConnectionManager

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Heartbeat Interval", isPresented: $showIntervalPicker, titleVisibility: .visible) {
                ForEach([(0, "Off"), (5, "5 min"), (10, "10 min"), (30, "30 min"), (60, "1 hour"), (120, "2 hours"), (240, "4 hours"), (480, "8 hours"), (1440, "1 day")], id: \.0) { minutes, label in
                    Button(label) {
                        let value = minutes == 0 ? nil : minutes
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
