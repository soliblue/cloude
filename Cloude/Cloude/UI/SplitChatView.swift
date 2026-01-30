//
//  SplitChatView.swift
//  Cloude
//
//  Multi-pane chat view supporting 1-4 simultaneous conversations
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

struct SplitChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var paneManager: PaneManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectingPane: ChatPane?
    @State private var isKeyboardVisible = false
    @State private var inputText = ""
    @State private var selectedImageData: Data?
    @State private var hasClipboardContent = false
    @State private var drafts: [UUID: (text: String, imageData: Data?)] = [:]
    @State private var gitBranches: [UUID: String] = [:]
    @State private var pendingGitChecks: [UUID] = []

    var body: some View {
        GeometryReader { geometry in
            paneGrid(geometry: geometry)
        }
        .onTapGesture {
            dismissKeyboard()
        }
        .safeAreaInset(edge: .bottom) {
            GlobalInputBar(
                inputText: $inputText,
                selectedImageData: $selectedImageData,
                hasClipboardContent: hasClipboardContent,
                isConnected: connection.isAuthenticated,
                isWhisperReady: connection.isWhisperReady,
                onSend: sendMessage,
                onTranscribe: transcribeAudio
            )
        }
        .onAppear {
            initializeFirstPane()
            checkClipboard()
            setupGitStatusHandler()
            checkGitForAllProjects()
            connection.onTranscription = { text in
                print("[iOS] Received transcription: \(text)")
                inputText = text
            }
        }
        .onChange(of: paneManager.activePaneId) { oldId, newId in
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
            if paneManager.panes.count == 1 { syncActivePaneToStore() }
        }
        .onChange(of: projectStore.currentConversation?.id) { _, _ in
            if paneManager.panes.count == 1 { updateActivePaneLink() }
        }
        .sheet(item: $selectingPane) { pane in
            PaneConversationPicker(
                projectStore: projectStore,
                onSelect: { project, conversation in
                    paneManager.linkToCurrentConversation(pane.id, project: project, conversation: conversation)
                    selectingPane = nil
                    if gitBranches[project.id] == nil, !project.rootDirectory.isEmpty {
                        pendingGitChecks = [project.id]
                        checkNextGitProject()
                    }
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
        .onChange(of: connection.isAuthenticated) { _, isAuth in
            if isAuth { checkGitForAllProjects() }
        }
        .onChange(of: connection.lastError) { _, error in
            if error != nil && !pendingGitChecks.isEmpty {
                pendingGitChecks.removeFirst()
                checkNextGitProject()
            }
        }
    }

    @ViewBuilder
    private func paneGrid(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(paneManager.panes) { pane in
                paneView(for: pane, totalHeight: geometry.size.height - 4)
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func paneView(for pane: ChatPane, totalHeight: CGFloat) -> some View {
        let project = pane.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        let conversation = project.flatMap { proj in
            pane.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
        let isActive = pane.id == paneManager.activePaneId
        let isThinking = pane.conversationId != nil && connection.runningConversationId == pane.conversationId
        let height = heightForPane(pane, totalHeight: totalHeight)

        VStack(spacing: 0) {
            paneTypeHeader(for: pane, project: project, conversation: conversation)
            Divider()
            paneContent(for: pane, project: project, conversation: conversation)
        }
        .frame(height: height)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            PulsingBorder(isActive: isActive, isThinking: isThinking)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            paneManager.setActive(pane.id)
        }
    }

    private func heightForPane(_ pane: ChatPane, totalHeight: CGFloat) -> CGFloat? {
        let count = paneManager.panes.count
        guard count > 1 else { return nil }

        let isActive = pane.id == paneManager.activePaneId
        let spacing = CGFloat(count - 1) * 2
        let availableHeight = totalHeight - spacing

        if isKeyboardVisible {
            let collapsedHeight: CGFloat = 44
            let totalCollapsedHeight = collapsedHeight * CGFloat(count - 1)
            if isActive {
                return availableHeight - totalCollapsedHeight
            } else {
                return collapsedHeight
            }
        }

        guard paneManager.focusModeEnabled else { return nil }

        if isActive {
            return availableHeight * 0.65
        } else {
            return availableHeight * 0.35 / CGFloat(count - 1)
        }
    }

    private func paneTypeHeader(for pane: ChatPane, project: Project?, conversation: Conversation?) -> some View {
        let gitBranch = project.flatMap { gitBranches[$0.id] }
        let availableTypes = PaneType.allCases.filter { type in
            if type == .gitChanges { return gitBranch != nil }
            return true
        }

        return HStack(spacing: 8) {
            ForEach(availableTypes, id: \.self) { type in
                Button(action: {
                    paneManager.setActive(pane.id)
                    paneManager.setPaneType(pane.id, type: type)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14))
                        if type == .gitChanges, let branch = gitBranch {
                            Text(branch)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(pane.type == type ? .accentColor : .secondary)
                    .padding(6)
                    .background(pane.type == type ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: {
                paneManager.setActive(pane.id)
                selectingPane = pane
            }) {
                HStack(spacing: 4) {
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let proj = project {
                            Text("• \(proj.name)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                paneManager.setActive(pane.id)
                if paneManager.panes.count == 1 {
                    addPaneWithNewChat()
                } else {
                    paneManager.removePane(pane.id)
                }
            }) {
                Image(systemName: paneManager.panes.count == 1 ? "plus" : "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .disabled(paneManager.panes.count == 1 && !paneManager.canAddPane)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private func paneContent(for pane: ChatPane, project: Project?, conversation: Conversation?) -> some View {
        let isActive = pane.id == paneManager.activePaneId
        let isCollapsed = isKeyboardVisible && !isActive && paneManager.panes.count > 1

        if isCollapsed {
            collapsedPaneContent(conversation: conversation)
        } else {
            switch pane.type {
            case .chat:
                chatPaneContent(for: pane, project: project, conversation: conversation)
            case .files:
                filesPaneContent(project: project)
            case .gitChanges:
                gitChangesPaneContent(project: project)
            }
        }
    }

    private func collapsedPaneContent(conversation: Conversation?) -> some View {
        EmptyView()
    }

    private func chatPaneContent(for pane: ChatPane, project: Project?, conversation: Conversation?) -> some View {
        ProjectChatView(
            connection: connection,
            store: projectStore,
            project: project,
            conversation: conversation,
            isCompact: true,
            onInteraction: {
                paneManager.setActive(pane.id)
                dismissKeyboard()
            }
        )
    }

    private func filesPaneContent(project: Project?) -> some View {
        FileBrowserView(
            connection: connection,
            rootPath: project?.rootDirectory
        )
    }

    private func gitChangesPaneContent(project: Project?) -> some View {
        GitChangesView(
            connection: connection,
            rootPath: project?.rootDirectory
        )
    }

    private func initializeFirstPane() {
        guard let firstPane = paneManager.panes.first,
              firstPane.conversationId == nil,
              let project = projectStore.currentProject,
              let conversation = projectStore.currentConversation else { return }
        paneManager.linkToCurrentConversation(firstPane.id, project: project, conversation: conversation)
    }

    private func addPaneWithNewChat() {
        var project = projectStore.currentProject
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        let newPaneId = paneManager.addPane()
        let newConv = projectStore.newConversation(in: proj)
        paneManager.linkToCurrentConversation(newPaneId, project: proj, conversation: newConv)
    }

    private func syncActivePaneToStore() {
        guard let activePane = paneManager.activePane else { return }
        if let projectId = activePane.projectId,
           let project = projectStore.projects.first(where: { $0.id == projectId }) {
            if let convId = activePane.conversationId,
               let conv = project.conversations.first(where: { $0.id == convId }) {
                projectStore.selectConversation(conv, in: project)
            } else {
                projectStore.selectProject(project)
            }
        }
    }

    private func updateActivePaneLink() {
        guard let activeId = paneManager.activePaneId else { return }
        paneManager.linkToCurrentConversation(
            activeId,
            project: projectStore.currentProject,
            conversation: projectStore.currentConversation
        )
    }

    private func checkClipboard() {
        hasClipboardContent = UIPasteboard.general.hasStrings
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = selectedImageData?.base64EncodedString()
        guard !text.isEmpty || imageBase64 != nil else { return }

        guard let activePane = paneManager.activePane else { return }

        var project = activePane.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        var conversation = proj.conversations.first { $0.id == activePane.conversationId }
        if conversation == nil {
            conversation = projectStore.newConversation(in: proj)
            paneManager.linkToCurrentConversation(activePane.id, project: proj, conversation: conversation)
        }
        guard let conv = conversation else { return }

        let isRunning = connection.runningConversationId == conv.id

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: imageBase64)
            projectStore.queueMessage(userMessage, to: conv, in: proj)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: imageBase64)
            projectStore.addMessage(userMessage, to: conv, in: proj)

            let isNewSession = conv.sessionId == nil
            let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: imageBase64)
        }

        inputText = ""
        selectedImageData = nil
        if let activeId = paneManager.activePaneId {
            drafts.removeValue(forKey: activeId)
        }
    }

    private func transcribeAudio(_ audioData: Data) {
        print("[iOS] Sending audio for transcription: \(audioData.count) bytes")
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func setupGitStatusHandler() {
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

    private func checkGitForAllProjects() {
        pendingGitChecks = projectStore.projects
            .filter { !$0.rootDirectory.isEmpty && gitBranches[$0.id] == nil }
            .map { $0.id }
        checkNextGitProject()
    }

    private func checkNextGitProject() {
        guard let projectId = pendingGitChecks.first,
              let project = projectStore.projects.first(where: { $0.id == projectId }) else { return }
        connection.gitStatus(path: project.rootDirectory)
    }
}

struct GlobalInputBar: View {
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    let hasClipboardContent: Bool
    let isConnected: Bool
    let isWhisperReady: Bool
    let onSend: () -> Void
    var onTranscribe: ((Data) -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var placeholderIndex = Int.random(in: 0..<20)
    @State private var textFieldId = UUID()

    private static let placeholders = [
        "fix the login bug pls",
        "why isn't the button showing",
        "make the font bigger",
        "add a back button here",
        "this crashes on launch",
        "deploy to testflight",
        "push to git",
        "can you add dark mode",
        "the animation is janky",
        "why is this so slow",
        "add a loading spinner",
        "make it look nicer",
        "refactor this mess",
        "write tests for this",
        "explain what this does",
        "add error handling pls",
        "the padding looks off",
        "can we cache this",
        "hide the keyboard on tap",
        "make it work offline"
    ]

    private var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        if inputText.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.secondary)
                                .id(placeholderIndex)
                                .transition(.opacity)
                        }
                        TextField("", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...4)
                            .focused($isInputFocused)
                            .onSubmit { if canSend { onSend() } }
                            .id(textFieldId)
                    }

                    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button(action: { selectedImageData = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }

                Button(action: toggleRecording) {
                    Image(systemName: micIcon)
                        .font(.system(size: 18))
                        .foregroundColor(micColor)
                }
                .disabled(!canRecord)

                Button(action: {
                    if inputText.isEmpty && hasClipboardContent {
                        if let text = UIPasteboard.general.string {
                            inputText = text
                        }
                    } else {
                        onSend()
                    }
                }) {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 18))
                        .foregroundColor(canSend ? .accentColor : .accentColor.opacity(0.4))
                }
                .disabled(!canSend && !hasClipboardContent)
            }
            .opacity(audioRecorder.isRecording ? 0.3 : 1.0)

            if audioRecorder.isRecording {
                RecordingOverlayView(
                    audioLevel: audioRecorder.audioLevel,
                    onStop: {
                        if let data = audioRecorder.stopRecording() {
                            onTranscribe?(data)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioRecorder.isRecording)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
        .onChange(of: inputText) { old, new in
            if !old.isEmpty && new.isEmpty {
                placeholderIndex = Int.random(in: 0..<Self.placeholders.count)
                textFieldId = UUID()
            }
        }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            if inputText.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
                }
            }
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }

    private var canRecord: Bool {
        isConnected && isWhisperReady && !audioRecorder.isTranscribing
    }

    private var actionButtonIcon: String {
        if inputText.isEmpty && !canSend {
            return "clipboard"
        }
        return "paperplane.fill"
    }

    private var micIcon: String {
        if audioRecorder.isTranscribing { return "ellipsis" }
        return audioRecorder.isRecording ? "stop.circle.fill" : "mic"
    }

    private var micColor: Color {
        if !canRecord { return .secondary.opacity(0.4) }
        return audioRecorder.isRecording ? .red : .accentColor
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            if let data = audioRecorder.stopRecording() {
                onTranscribe?(data)
            }
        } else {
            audioRecorder.requestPermission { granted in
                if granted {
                    audioRecorder.startRecording()
                }
            }
        }
    }
}

struct PulsingBorder: View {
    let isActive: Bool
    let isThinking: Bool

    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: isActive ? 1.5 : 0.5)
            .opacity(isThinking ? (pulse ? 0.4 : 1.0) : 1.0)
            .animation(isThinking ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear {
                if isThinking { pulse = true }
            }
            .onChange(of: isThinking) { _, thinking in
                pulse = thinking
            }
    }

    private var borderColor: Color {
        if isThinking {
            return .orange
        }
        return isActive ? .accentColor : Color(.separator)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
