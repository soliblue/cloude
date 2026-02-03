import SwiftUI
import Combine
import CloudeShared
import AVFoundation
import UIKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@main
struct CloudeApp: App {
    @StateObject private var connection = ConnectionManager()
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var windowManager = WindowManager()
    @StateObject private var heartbeatStore = HeartbeatStore()
    @State private var showSettings = false
    @State private var showMemories = false
    @State private var memorySections: [MemorySection] = []
    @State private var isLoadingMemories = false
    @State private var wasBackgrounded = false
    @State private var lastActiveSessionId: String? = nil
    @State private var isUnlocked = false
    @State private var filePathToPreview: String? = nil
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if requireBiometricAuth && !isUnlocked {
                    LockScreenView(onUnlock: { isUnlocked = true })
                } else {
                    mainContent
                }
            }
            .preferredColorScheme(appTheme.colorScheme)
        }
    }

    private var mainContent: some View {
        NavigationStack {
            MainChatView(connection: connection, projectStore: projectStore, windowManager: windowManager, heartbeatStore: heartbeatStore)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            isLoadingMemories = true
                            memorySections = []
                            connection.send(.getMemories)
                            showMemories = true
                        }) {
                            Image(systemName: "brain")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        ConnectionStatusLogo(connection: connection)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .padding(4)
                        }
                    }
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connection: connection)
        }
        .sheet(isPresented: $showMemories) {
            MemoriesSheet(sections: memorySections, isLoading: isLoadingMemories)
        }
        .sheet(item: $filePathToPreview) { path in
            FilePathPreviewView(path: path, connection: connection)
        }
        .onOpenURL { url in
            guard url.scheme == "cloude" else { return }
            switch url.host {
            case "file":
                let path = url.path.removingPercentEncoding ?? url.path
                filePathToPreview = path
            case "memory":
                isLoadingMemories = true
                memorySections = []
                connection.send(.getMemories)
                showMemories = true
            default:
                break
            }
        }
        .onAppear { loadAndConnect() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                wasBackgrounded = true
                lastActiveSessionId = projectStore.currentConversation?.sessionId
                if requireBiometricAuth {
                    isUnlocked = false
                }
            } else if newPhase == .active {
                if wasBackgrounded {
                    connection.clearAllRunningStates()
                }
                connection.reconnectIfNeeded()
                if wasBackgrounded, let sessionId = lastActiveSessionId {
                    connection.requestMissedResponse(sessionId: sessionId)
                }
                wasBackgrounded = false
            }
        }
    }

    private func loadAndConnect() {
        NotificationManager.requestPermission()

        let host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
        let portString = UserDefaults.standard.string(forKey: "serverPort") ?? "8765"
        let token = KeychainHelper.get(key: "authToken") ?? ""

        guard !host.isEmpty, !token.isEmpty, let port = UInt16(portString) else {
            showSettings = true
            return
        }

        connection.onMissedResponse = { [projectStore] _, text, toolCalls, _, interruptedConvId, interruptedMsgId in
            if let convId = interruptedConvId,
               let msgId = interruptedMsgId,
               let (project, conv) = projectStore.findConversation(withId: convId) {
                projectStore.updateMessage(msgId, in: conv, in: project) { msg in
                    msg.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    msg.toolCalls = toolCalls
                    msg.wasInterrupted = false
                }
                projectStore.objectWillChange.send()
            } else if let project = projectStore.currentProject,
                      let conversation = projectStore.currentConversation {
                let message = ChatMessage(isUser: false, text: text.trimmingCharacters(in: .whitespacesAndNewlines), toolCalls: toolCalls)
                projectStore.addMessage(message, to: conversation, in: project)
            }
        }

        connection.onDisconnect = { [projectStore, connection] convId, output in
            guard !output.text.isEmpty else { return }
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                let message = ChatMessage(
                    isUser: false,
                    text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    toolCalls: output.toolCalls,
                    wasInterrupted: true
                )
                projectStore.addMessage(message, to: conv, in: project)
                if let sessionId = output.newSessionId {
                    connection.interruptedSession = (convId, sessionId, message.id)
                }
                output.reset()
            }
        }

        connection.onMemories = { sections in
            memorySections = sections
            isLoadingMemories = false
        }

        connection.onRenameConversation = { [projectStore] convId, name in
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                projectStore.renameConversation(conv, in: project, to: name)
            }
        }

        connection.onSetConversationSymbol = { [projectStore] convId, symbol in
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                projectStore.setConversationSymbol(conv, in: project, symbol: symbol)
            }
        }

        connection.onSessionIdReceived = { [projectStore] convId, sessionId in
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                let workingDir = project.rootDirectory.isEmpty ? nil : project.rootDirectory
                projectStore.updateSessionId(conv, in: project, sessionId: sessionId, workingDirectory: workingDir)
            }
        }

        connection.onHistorySync = { [projectStore] sessionId, historyMessages in
            if let (project, conv) = projectStore.findConversation(withSessionId: sessionId) {
                let newMessages = historyMessages.map { msg in
                    let toolCalls = msg.toolCalls.map { ToolCall(name: $0.name, input: $0.input, toolId: $0.toolId, parentToolId: $0.parentToolId, textPosition: $0.textPosition) }
                    return ChatMessage(isUser: msg.isUser, text: msg.text, timestamp: msg.timestamp, toolCalls: toolCalls)
                }
                projectStore.replaceMessages(conv, in: project, with: newMessages)
            }
        }

        connection.onDeleteConversation = { [projectStore] convId in
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                projectStore.deleteConversation(conv, from: project)
            }
        }

        connection.onNotify = { title, body in
            NotificationManager.showCustomNotification(title: title, body: body)
        }

        connection.onClipboard = { text in
            UIPasteboard.general.string = text
        }

        connection.onOpenURL = { urlString in
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }

        connection.onHaptic = { style in
            let generator: UIImpactFeedbackGenerator
            switch style {
            case "light": generator = UIImpactFeedbackGenerator(style: .light)
            case "heavy": generator = UIImpactFeedbackGenerator(style: .heavy)
            case "rigid": generator = UIImpactFeedbackGenerator(style: .rigid)
            case "soft": generator = UIImpactFeedbackGenerator(style: .soft)
            default: generator = UIImpactFeedbackGenerator(style: .medium)
            }
            generator.impactOccurred()
        }

        connection.onSpeak = { text in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            AVSpeechSynthesizer().speak(utterance)
        }

        connection.onSwitchConversation = { [projectStore] convId in
            if let (project, conv) = projectStore.findConversation(withId: convId) {
                projectStore.selectConversation(conv, in: project)
            }
        }

        connection.onQuestion = { [projectStore] questions, convId in
            if let convId = convId {
                projectStore.pendingQuestion = PendingQuestion(conversationId: convId, questions: questions)
            } else if let currentId = projectStore.currentConversation?.id {
                projectStore.pendingQuestion = PendingQuestion(conversationId: currentId, questions: questions)
            }
        }

        connection.connect(host: host, port: port, token: token)
    }
}
