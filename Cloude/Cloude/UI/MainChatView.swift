import SwiftUI
import UIKit
import Combine
import CloudeShared

struct MainChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var heartbeatStore: HeartbeatStore
    @State var selectingWindow: ChatWindow?
    @State var editingWindow: ChatWindow?
    @State var currentPageIndex: Int = 0
    @State var isKeyboardVisible = false
    @State var inputText = ""
    @State var selectedImageData: Data?
    @State var drafts: [UUID: (text: String, imageData: Data?)] = [:]
    @State var gitBranches: [UUID: String] = [:]
    @State var pendingGitChecks: [UUID] = []
    @State var showIntervalPicker = false

    private var isHeartbeatActive: Bool { currentPageIndex == 0 }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentPageIndex) {
                heartbeatWindowContent()
                    .tag(0)

                ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                    pagedWindowContent(for: window)
                        .tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPageIndex) { _, newIndex in
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
        }
        .onTapGesture {
            dismissKeyboard()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                GlobalInputBar(
                    inputText: $inputText,
                    selectedImageData: $selectedImageData,
                    isConnected: connection.isAuthenticated,
                    isWhisperReady: connection.isWhisperReady,
                    isRunning: activeConversationIsRunning,
                    skills: connection.skills,
                    onSend: sendMessage,
                    onStop: stopActiveConversation,
                    onTranscribe: transcribeAudio
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
            checkGitForAllProjects()
            connection.onTranscription = { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBlank = trimmed.isEmpty ||
                    trimmed.contains("blank audio") ||
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
            }
        }
        .onChange(of: windowManager.activeWindowId) { oldId, newId in
            if let oldId = oldId {
                if !inputText.isEmpty || selectedImageData != nil {
                    drafts[oldId] = (inputText, selectedImageData)
                } else {
                    drafts.removeValue(forKey: oldId)
                }
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
        .onChange(of: projectStore.currentConversation?.id) { _, _ in
            if windowManager.windows.count == 1 { updateActiveWindowLink() }
        }
        .sheet(item: $selectingWindow) { window in
            WindowConversationPicker(
                projectStore: projectStore,
                connection: connection,
                onSelect: { project, conversation in
                    windowManager.linkToCurrentConversation(window.id, project: project, conversation: conversation)
                    selectingWindow = nil
                    if gitBranches[project.id] == nil, !project.rootDirectory.isEmpty {
                        pendingGitChecks = [project.id]
                        checkNextGitProject()
                    }
                }
            )
        }
        .sheet(item: $editingWindow) { window in
            WindowEditSheet(
                window: window,
                projectStore: projectStore,
                windowManager: windowManager,
                onSelectConversation: { conv in
                    if let projectId = window.projectId,
                       let project = projectStore.projects.first(where: { $0.id == projectId }) {
                        windowManager.linkToCurrentConversation(window.id, project: project, conversation: conv)
                    }
                    editingWindow = nil
                },
                onShowAllConversations: {
                    editingWindow = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectingWindow = window
                    }
                },
                onNewConversation: {
                    if let projectId = window.projectId,
                       let project = projectStore.projects.first(where: { $0.id == projectId }) {
                        let newConv = projectStore.newConversation(in: project)
                        windowManager.linkToCurrentConversation(window.id, project: project, conversation: newConv)
                    }
                    editingWindow = nil
                },
                onDismiss: { editingWindow = nil }
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
                heartbeatStore.markRead()
            }
        }
        .confirmationDialog("Heartbeat Interval", isPresented: $showIntervalPicker, titleVisibility: .visible) {
            ForEach([(0, "Off"), (5, "5 min"), (10, "10 min"), (30, "30 min"), (60, "1 hour"), (120, "2 hours"), (240, "4 hours"), (480, "8 hours"), (1440, "1 day")], id: \.0) { minutes, label in
                Button(label) {
                    let value = minutes == 0 ? nil : minutes
                    heartbeatStore.intervalMinutes = value
                    connection.send(.setHeartbeatInterval(minutes: value))
                }
            }
        }
        .onAppear {
            connection.onHeartbeatConfig = { intervalMinutes, unreadCount in
                heartbeatStore.handleConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount)
            }
        }
    }

    @ViewBuilder
    func heartbeatWindowContent() -> some View {
        let convOutput = connection.output(for: Heartbeat.conversationId)

        VStack(spacing: 0) {
            heartbeatHeader(isRunning: convOutput.isRunning)

            HeartbeatChatView(
                heartbeatStore: heartbeatStore,
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
                Image(systemName: "bolt.heart")
                    .font(.system(size: 17))
                    .foregroundColor(isRunning ? .secondary : .accentColor)
            }
            .disabled(isRunning)
            .buttonStyle(.plain)
            .padding(7)

            Spacer()

            VStack(spacing: 2) {
                Text("Heartbeat")
                    .font(.caption)
                    .fontWeight(.medium)
                if isRunning {
                    Text("Running...")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                } else {
                    Text("Last: \(heartbeatStore.lastTriggeredDisplayText)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { showIntervalPicker = true }) {
                if heartbeatStore.intervalMinutes == nil {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 17))
                } else {
                    Text(heartbeatStore.intervalDisplayText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .padding(7)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemBackground))
    }

    private func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        heartbeatStore.recordTrigger()
        connection.send(.triggerHeartbeat)
    }

    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let project = window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        let conversation = project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }

        VStack(spacing: 0) {
            windowHeader(for: window, project: project, conversation: conversation)

            switch window.type {
            case .chat:
                ProjectChatView(
                    connection: connection,
                    store: projectStore,
                    project: project,
                    conversation: conversation,
                    isCompact: false,
                    isKeyboardVisible: isKeyboardVisible,
                    onInteraction: { dismissKeyboard() }
                )
            case .files:
                FileBrowserView(
                    connection: connection,
                    rootPath: project?.rootDirectory
                )
            case .gitChanges:
                GitChangesView(
                    connection: connection,
                    rootPath: project?.rootDirectory
                )
            }
        }
    }

    func windowHeader(for window: ChatWindow, project: Project?, conversation: Conversation?) -> some View {
        let gitBranch = project.flatMap { gitBranches[$0.id] }
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
                    HStack(spacing: 5) {
                        Image(systemName: type.icon)
                            .font(.system(size: 17))
                        if type == .gitChanges, let branch = gitBranch {
                            Text(branch)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(window.type == type ? .accentColor : .secondary)
                    .opacity(window.type == type && isStreaming ? 0.4 : 1.0)
                    .padding(7)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                HStack(spacing: 5) {
                    if let symbol = conversation?.symbol, !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.system(size: 15))
                    }
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
                    if let proj = project {
                        Text("• \(proj.name)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
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
        .background(Color(.secondarySystemBackground))
    }

    func pageIndicator() -> some View {
        HStack(spacing: 16) {
            heartbeatIndicatorButton()
            windowIndicatorButtons()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func heartbeatIndicatorButton() -> some View {
        let isStreaming = connection.output(for: Heartbeat.conversationId).isRunning
        let weight: Font.Weight = isHeartbeatActive || isStreaming ? .semibold : .regular
        let color: Color = isHeartbeatActive ? .pink : (isStreaming ? .accentColor : .secondary)

        Button {
            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = 0 }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: weight))
                    .foregroundStyle(color)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))

                if heartbeatStore.unreadCount > 0 && !isHeartbeatActive {
                    Text(heartbeatStore.unreadCount > 9 ? "9+" : "\(heartbeatStore.unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Circle().fill(.red))
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
            let conversation = window.projectId.flatMap { pid in
                projectStore.projects.first { $0.id == pid }
            }.flatMap { proj in
                window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
            }

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

        if let symbol = conversation?.symbol, !symbol.isEmpty {
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
            sendProjectMessage(text: text, imageBase64: fullImageBase64, thumbnailBase64: thumbnailBase64)
        }

        inputText = ""
        selectedImageData = nil
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }
    }

    private func sendHeartbeatMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
        let convOutput = connection.output(for: Heartbeat.conversationId)

        if convOutput.isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            heartbeatStore.conversation.pendingMessages.append(userMessage)
            heartbeatStore.save()
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            heartbeatStore.conversation.messages.append(userMessage)
            heartbeatStore.save()

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

    private func sendProjectMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        var project = activeWindow.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        var conversation = proj.conversations.first { $0.id == activeWindow.conversationId }
        if conversation == nil {
            conversation = projectStore.newConversation(in: proj)
            windowManager.linkToCurrentConversation(activeWindow.id, project: proj, conversation: conversation)
        }
        guard let conv = conversation else { return }

        let isRunning = connection.output(for: conv.id).isRunning

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            projectStore.queueMessage(userMessage, to: conv, in: proj)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            projectStore.addMessage(userMessage, to: conv, in: proj)

            let isNewSession = conv.sessionId == nil
            let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: imageBase64, conversationName: conv.name, conversationSymbol: conv.symbol)
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
              let project = projectStore.currentProject,
              let conversation = projectStore.currentConversation else { return }
        windowManager.linkToCurrentConversation(firstWindow.id, project: project, conversation: conversation)
    }

    func addWindowWithNewChat() {
        var project = projectStore.currentProject
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        let newWindowId = windowManager.addWindow()
        let newConv = projectStore.newConversation(in: proj)
        windowManager.linkToCurrentConversation(newWindowId, project: proj, conversation: newConv)
    }

    func syncActiveWindowToStore() {
        guard let activeWindow = windowManager.activeWindow else { return }
        if let projectId = activeWindow.projectId,
           let project = projectStore.projects.first(where: { $0.id == projectId }) {
            if let convId = activeWindow.conversationId,
               let conv = project.conversations.first(where: { $0.id == convId }) {
                projectStore.selectConversation(conv, in: project)
            } else {
                projectStore.selectProject(project)
            }
        }
    }

    func updateActiveWindowLink() {
        guard let activeId = windowManager.activeWindowId else { return }
        windowManager.linkToCurrentConversation(
            activeId,
            project: projectStore.currentProject,
            conversation: projectStore.currentConversation
        )
    }

    func setupGitStatusHandler() {
        connection.onGitStatus = { status in
            if let projectId = pendingGitChecks.first {
                pendingGitChecks.removeFirst()
                if !status.branch.isEmpty {
                    gitBranches[projectId] = status.branch
                }
                checkNextGitProject()
            }
        }
    }

    func checkGitForAllProjects() {
        pendingGitChecks = projectStore.projects
            .filter { !$0.rootDirectory.isEmpty && gitBranches[$0.id] == nil }
            .map { $0.id }
        checkNextGitProject()
    }

    func checkNextGitProject() {
        guard let projectId = pendingGitChecks.first,
              let project = projectStore.projects.first(where: { $0.id == projectId }) else { return }
        connection.gitStatus(path: project.rootDirectory)
    }
}

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isStreaming ? (isPulsing ? 0.4 : 1.0) : 1.0)
            .animation(isStreaming ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isPulsing)
            .onChange(of: isStreaming) { _, streaming in
                isPulsing = streaming
            }
            .onAppear {
                if isStreaming { isPulsing = true }
            }
    }
}
