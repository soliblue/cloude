import SwiftUI
import UIKit
import Combine
import CloudeShared

struct MainChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @State var selectingWindow: ChatWindow?
    @State var editingWindow: ChatWindow?
    @State var currentPageIndex: Int = 0
    @State var isKeyboardVisible = false
    @State var inputText = ""
    @State var selectedImageData: Data?
    @State var drafts: [UUID: (text: String, imageData: Data?)] = [:]
    @State var gitBranches: [String: String] = [:]
    @State var pendingGitChecks: [String] = []
    @State var showIntervalPicker = false
    @State var fileSearchResults: [String] = []
    @State var currentEffort: EffortLevel?

    private var isHeartbeatActive: Bool { currentPageIndex == 0 }

    private var currentConversation: Conversation? {
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
                    selectedImageData: $selectedImageData,
                    isConnected: connection.isAuthenticated,
                    isWhisperReady: connection.isWhisperReady,
                    isTranscribing: connection.isTranscribing,
                    isRunning: activeConversationIsRunning,
                    skills: connection.skills,
                    fileSearchResults: fileSearchResults,
                    conversationDefaultEffort: currentConversation?.defaultEffort,
                    onSend: sendMessage,
                    onEffortChange: { currentEffort = $0 },
                    onStop: stopActiveConversation,
                    onTranscribe: transcribeAudio,
                    onFileSearch: searchFiles
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
                if !inputText.isEmpty || selectedImageData != nil {
                    drafts[oldId] = (inputText, selectedImageData)
                } else {
                    drafts.removeValue(forKey: oldId)
                }
                cleanupEmptyConversation(for: oldId)
            }
            if let newId = newId, let draft = drafts[newId] {
                inputText = draft.text
                selectedImageData = draft.imageData
            } else {
                inputText = ""
                selectedImageData = nil
            }
            if windowManager.windows.count == 1 { syncActiveWindowToStore() }
        }
        .onChange(of: conversationStore.currentConversation?.id) { _, _ in
            if windowManager.windows.count == 1 { updateActiveWindowLink() }
        }
        .sheet(item: $selectingWindow) { window in
            WindowConversationPicker(
                conversationStore: conversationStore,
                windowManager: windowManager,
                connection: connection,
                currentWindowId: window.id,
                onSelect: { conversation in
                    if let oldConvId = window.conversationId,
                       let oldConv = conversationStore.conversation(withId: oldConvId),
                       oldConv.isEmpty {
                        conversationStore.deleteConversation(oldConv)
                    }
                    windowManager.linkToCurrentConversation(window.id, conversation: conversation)
                    selectingWindow = nil
                    if let dir = conversation.workingDirectory, !dir.isEmpty, gitBranches[dir] == nil {
                        pendingGitChecks = [dir]
                        checkNextGitDirectory()
                    }
                }
            )
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
                onShowAllConversations: {
                    editingWindow = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectingWindow = window
                    }
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
    func heartbeatWindowContent() -> some View {
        let convOutput = connection.output(for: Heartbeat.conversationId)

        VStack(spacing: 0) {
            heartbeatHeader(isRunning: convOutput.isRunning)

            HeartbeatChatView(
                conversationStore: conversationStore,
                connection: connection,
                inputText: $inputText,
                selectedImageData: $selectedImageData,
                isKeyboardVisible: isKeyboardVisible
            )
        }
    }

    func heartbeatHeader(isRunning: Bool) -> some View {
        HStack(spacing: 9) {
            Button(action: triggerHeartbeat) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isRunning ? .secondary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isRunning ? Color.secondary.opacity(0.2) : Color.accentColor)
                    )
            }
            .disabled(isRunning)
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                if isRunning {
                    Text("Running...")
                        .foregroundColor(.orange)
                } else {
                    Text(conversationStore.heartbeatConfig.lastTriggeredDisplayText)
                }
                Text("•")
                    .foregroundColor(.secondary)
                Text("Heartbeat")
            }
            .font(.caption)
            .fontWeight(.medium)

            Spacer()

            Button(action: { showIntervalPicker = true }) {
                if conversationStore.heartbeatConfig.intervalMinutes == nil {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 17))
                } else {
                    Text(conversationStore.heartbeatConfig.intervalDisplayText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .padding(7)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.oceanSecondary)
    }

    private func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        conversationStore.recordHeartbeatTrigger()
        connection.send(.triggerHeartbeat)
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
                    onShowAllConversations: {
                        selectingWindow = window
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
        let gitBranch = workingDir.isEmpty ? nil : gitBranches[workingDir]
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
                    if let folder = conversation?.workingDirectory.flatMap({ path in
                        path.isEmpty ? nil : (path as NSString).lastPathComponent
                    }) {
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

    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count
        HStack(spacing: 16) {
            heartbeatIndicatorButton()
            windowIndicatorButtons()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > vertical else { return }
                    if value.translation.width > 0 && currentPageIndex < maxIndex {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex += 1 }
                    } else if value.translation.width < 0 && currentPageIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex -= 1 }
                    }
                }
        )
    }

    @ViewBuilder
    private func heartbeatIndicatorButton() -> some View {
        let isStreaming = connection.output(for: Heartbeat.conversationId).isRunning

        Button {
            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = 0 }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isHeartbeatActive ? "heart.circle.fill" : "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))

                if conversationStore.heartbeatConfig.unreadCount > 0 && !isHeartbeatActive {
                    Text(conversationStore.heartbeatConfig.unreadCount > 9 ? "9+" : "\(conversationStore.heartbeatConfig.unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func windowIndicatorButtons() -> some View {
        ForEach(0..<5, id: \.self) { index in
            windowIndicatorButton(at: index)
        }
    }

    @ViewBuilder
    private func windowIndicatorButton(at index: Int) -> some View {
        if index < windowManager.windows.count {
            let window = windowManager.windows[index]
            let isActive = currentPageIndex == index + 1
            let convId = window.conversationId
            let isStreaming = convId.map { connection.output(for: $0).isRunning } ?? false
            let conversation = window.conversationId.flatMap { conversationStore.conversation(withId: $0) }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = index + 1 }
            } label: {
                windowIndicatorIcon(conversation: conversation, isActive: isActive, isStreaming: isStreaming)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture().onEnded { _ in
                    editingWindow = window
                }
            )
        } else {
            Button(action: addWindowWithNewChat) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func windowIndicatorIcon(conversation: Conversation?, isActive: Bool, isStreaming: Bool) -> some View {
        let weight: Font.Weight = isActive || isStreaming ? .semibold : .regular
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        if let symbol = conversation?.symbol, symbol.isValidSFSymbol {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: weight))
                .foregroundStyle(color)
                .modifier(StreamingPulseModifier(isStreaming: isStreaming))
        } else {
            let size: CGFloat = isActive || isStreaming ? 12 : 8
            Circle()
                .fill(color.opacity(isActive || isStreaming ? 1.0 : 0.3))
                .frame(width: size, height: size)
                .modifier(StreamingPulseModifier(isStreaming: isStreaming))
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullImageBase64 = selectedImageData?.base64EncodedString()

        var thumbnailBase64: String? = nil
        if let imageData = selectedImageData,
           let image = UIImage(data: imageData),
           let thumbnail = image.preparingThumbnail(of: CGSize(width: 200, height: 200)),
           let thumbData = thumbnail.jpegData(compressionQuality: 0.7) {
            thumbnailBase64 = thumbData.base64EncodedString()
        }

        guard !text.isEmpty || fullImageBase64 != nil else { return }

        if isHeartbeatActive {
            sendHeartbeatMessage(text: text, imageBase64: fullImageBase64, thumbnailBase64: thumbnailBase64)
        } else {
            sendConversationMessage(text: text, imageBase64: fullImageBase64, thumbnailBase64: thumbnailBase64)
        }

        inputText = ""
        selectedImageData = nil
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }
    }

    private func sendHeartbeatMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
        let convOutput = connection.output(for: Heartbeat.conversationId)
        let heartbeat = conversationStore.heartbeatConversation

        if convOutput.isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            conversationStore.queueMessage(userMessage, to: heartbeat)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            conversationStore.addMessage(userMessage, to: heartbeat)

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: Heartbeat.sessionId,
                isNewSession: false,
                conversationId: Heartbeat.conversationId,
                imageBase64: imageBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill"
            )
        }
    }

    private func sendConversationMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        var conversation = activeWindow.conversationId.flatMap { conversationStore.conversation(withId: $0) }
        if conversation == nil {
            let workingDir = activeWindowWorkingDirectory()
            conversation = conversationStore.newConversation(workingDirectory: workingDir)
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        guard let conv = conversation else { return }

        let isRunning = connection.output(for: conv.id).isRunning

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            conversationStore.queueMessage(userMessage, to: conv)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            conversationStore.addMessage(userMessage, to: conv)

            let isFork = conv.pendingFork
            let isNewSession = conv.sessionId == nil && !isFork
            let workingDir = conv.workingDirectory
            let effortValue = (currentEffort ?? conv.defaultEffort)?.rawValue
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: imageBase64, conversationName: conv.name, conversationSymbol: conv.symbol, forkSession: isFork, effort: effortValue)

            if isFork {
                conversationStore.clearPendingFork(conv)
            }
        }
    }

    func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var activeConversationIsRunning: Bool {
        if isHeartbeatActive {
            return connection.output(for: Heartbeat.conversationId).isRunning
        }
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId else { return false }
        return connection.output(for: convId).isRunning
    }

    func stopActiveConversation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if isHeartbeatActive {
            connection.abort(conversationId: Heartbeat.conversationId)
        } else if let activeWindow = windowManager.activeWindow,
                  let convId = activeWindow.conversationId {
            connection.abort(conversationId: convId)
        }
    }

    func initializeFirstWindow() {
        guard let firstWindow = windowManager.windows.first,
              firstWindow.conversationId == nil,
              let conversation = conversationStore.currentConversation else { return }
        windowManager.linkToCurrentConversation(firstWindow.id, conversation: conversation)
    }

    func addWindowWithNewChat() {
        let activeWorkingDir = activeWindowWorkingDirectory()
        let newWindowId = windowManager.addWindow()
        let newConv = conversationStore.newConversation(workingDirectory: activeWorkingDir)
        windowManager.linkToCurrentConversation(newWindowId, conversation: newConv)
    }

    func activeWindowWorkingDirectory() -> String? {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else {
            return conversationStore.currentConversation?.workingDirectory
        }
        return conv.workingDirectory
    }

    func syncActiveWindowToStore() {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else { return }
        conversationStore.selectConversation(conv)
    }

    func updateActiveWindowLink() {
        guard let activeId = windowManager.activeWindowId else { return }
        windowManager.linkToCurrentConversation(
            activeId,
            conversation: conversationStore.currentConversation
        )
    }

    func setupGitStatusHandler() {
        connection.onGitStatus = { status in
            if let dir = pendingGitChecks.first {
                pendingGitChecks.removeFirst()
                if !status.branch.isEmpty {
                    gitBranches[dir] = status.branch
                }
                checkNextGitDirectory()
            }
        }
    }

    func checkGitForAllDirectories() {
        pendingGitChecks = conversationStore.uniqueWorkingDirectories
            .filter { gitBranches[$0] == nil }
        checkNextGitDirectory()
    }

    func checkNextGitDirectory() {
        guard let dir = pendingGitChecks.first, !dir.isEmpty else { return }
        connection.gitStatus(path: dir)
    }

    func cleanupEmptyConversation(for windowId: UUID) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }),
              let convId = window.conversationId,
              let conversation = conversationStore.conversation(withId: convId),
              conversation.isEmpty else { return }
        conversationStore.deleteConversation(conversation)
        windowManager.unlinkConversation(windowId)
    }

    func searchFiles(_ query: String) {
        guard let workingDir = activeWindowWorkingDirectory(), !workingDir.isEmpty else {
            fileSearchResults = []
            return
        }
        connection.searchFiles(query: query, workingDirectory: workingDir)
    }

    func setupFileSearchHandler() {
        connection.onFileSearchResults = { files, _ in
            fileSearchResults = files
        }
    }

    func setupCostHandler() {
        connection.onLastAssistantMessageCostUpdate = { [conversationStore] convId, costUsd in
            guard let conversation = conversationStore.conversation(withId: convId),
                  let lastAssistantMsg = conversation.messages.last(where: { !$0.isUser }) else { return }
            conversationStore.updateMessage(lastAssistantMsg.id, in: conversation) { msg in
                msg.costUsd = costUsd
            }
        }
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
