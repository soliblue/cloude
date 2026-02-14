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
    @StateObject private var conversationStore = ConversationStore()
    @StateObject private var windowManager = WindowManager()
    @State private var showSettings = false
    @State private var showMemories = false
    @State private var memorySections: [MemorySection] = []
    @State private var isLoadingMemories = false
    @State private var showPlans = false
    @State private var planStages: [String: [PlanItem]] = [:]
    @State private var isLoadingPlans = false
    @State private var wasBackgrounded = false
    @State private var lastActiveSessionId: String? = nil
    @State private var isUnlocked = false
    @State private var filePathToPreview: String? = nil
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark
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
            MainChatView(connection: connection, conversationStore: conversationStore, windowManager: windowManager)
            .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 0) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            Divider().frame(height: 20).padding(.horizontal, 10)
                            Button(action: {
                                isLoadingMemories = true
                                memorySections = []
                                connection.send(.getMemories)
                                showMemories = true
                            }) {
                                Image(systemName: "brain")
                            }
                            Divider().frame(height: 20).padding(.horizontal, 10)
                            Button(action: {
                                isLoadingPlans = true
                                planStages = [:]
                                if let wd = conversationStore.currentConversation?.workingDirectory ?? connection.defaultWorkingDirectory {
                                    connection.getPlans(workingDirectory: wd)
                                }
                                showPlans = true
                            }) {
                                Image(systemName: "list.bullet.clipboard")
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    ToolbarItem(placement: .principal) {
                        ConnectionStatusLogo(connection: connection)
                            .padding(.leading, 40)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            if connection.isAuthenticated || connection.isConnected {
                                connection.disconnect(clearCredentials: false)
                            } else {
                                connection.reconnectIfNeeded()
                            }
                        }) {
                            Image(systemName: "power")
                                .foregroundStyle(connection.isAuthenticated || connection.isConnected ? Color.accentColor : .secondary)
                        }
                    }
                }
        }
        .onReceive(connection.events, perform: handleConnectionEvent)
        .sheet(isPresented: $showSettings) {
            SettingsView(connection: connection)
        }
        .sheet(isPresented: $showMemories) {
            MemoriesSheet(sections: memorySections, isLoading: isLoadingMemories)
        }
        .sheet(isPresented: $showPlans) {
            PlansSheet(
                stages: planStages,
                isLoading: isLoadingPlans,
                onOpenFile: { path in
                    showPlans = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        filePathToPreview = path
                    }
                }
            )
        }
        .sheet(item: $filePathToPreview) { path in
            FilePreviewView(path: path, connection: connection)
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
                lastActiveSessionId = conversationStore.currentConversation?.sessionId
                if requireBiometricAuth {
                    isUnlocked = false
                }
                connection.beginBackgroundStreamingIfNeeded()
            } else if newPhase == .active {
                connection.endBackgroundStreaming()
                if wasBackgrounded && !connection.isAnyRunning {
                    connection.clearAllRunningStates()
                }
                connection.reconnectIfNeeded()
                if wasBackgrounded && !connection.isAnyRunning, let sessionId = lastActiveSessionId {
                    connection.requestMissedResponse(sessionId: sessionId)
                }
                wasBackgrounded = false
            }
        }
    }

    private func handleConnectionEvent(_ event: ConnectionEvent) {
        switch event {
        case .missedResponse(_, let text, _, let storedToolCalls, let interruptedConvId, let interruptedMsgId):
            let toolCalls = storedToolCalls.map {
                ToolCall(
                    name: $0.name,
                    input: $0.input,
                    toolId: $0.toolId,
                    parentToolId: $0.parentToolId,
                    textPosition: $0.textPosition
                )
            }
            if let convId = interruptedConvId,
               let msgId = interruptedMsgId,
               let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.updateMessage(msgId, in: conv) { msg in
                    msg.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    msg.toolCalls = toolCalls
                    msg.wasInterrupted = false
                }
                conversationStore.objectWillChange.send()
            } else if let conversation = conversationStore.currentConversation {
                let message = ChatMessage(isUser: false, text: text.trimmingCharacters(in: .whitespacesAndNewlines), toolCalls: toolCalls)
                conversationStore.addMessage(message, to: conversation)
            }

        case .disconnect(let convId, let output):
            guard !output.text.isEmpty else { return }
            if let conv = conversationStore.findConversation(withId: convId) {
                let message = ChatMessage(
                    isUser: false,
                    text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    toolCalls: output.toolCalls,
                    wasInterrupted: true
                )
                conversationStore.addMessage(message, to: conv)
                if let sessionId = output.newSessionId {
                    connection.interruptedSession = (convId, sessionId, message.id)
                }
                output.reset()
            }

        case .memories(let sections):
            memorySections = sections
            isLoadingMemories = false

        case .plans(let stages):
            planStages = stages
            isLoadingPlans = false

        case .planDeleted(let stage, let filename):
            planStages[stage]?.removeAll { $0.filename == filename }

        case .renameConversation(let convId, let name):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.renameConversation(conv, to: name)
            }

        case .setConversationSymbol(let convId, let symbol):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.setConversationSymbol(conv, symbol: symbol)
            }

        case .sessionIdReceived(let convId, let sessionId):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.updateSessionId(conv, sessionId: sessionId, workingDirectory: conv.workingDirectory)
            }

        case .historySync(let sessionId, let historyMessages):
            if let conv = conversationStore.findConversation(withSessionId: sessionId) {
                let newMessages = historyMessages.map { msg in
                    let toolCalls = msg.toolCalls.map {
                        ToolCall(
                            name: $0.name,
                            input: $0.input,
                            toolId: $0.toolId,
                            parentToolId: $0.parentToolId,
                            textPosition: $0.textPosition
                        )
                    }
                    return ChatMessage(
                        isUser: msg.isUser,
                        text: msg.text,
                        timestamp: msg.timestamp,
                        toolCalls: toolCalls,
                        serverUUID: msg.serverUUID,
                        model: msg.model
                    )
                }
                conversationStore.replaceMessages(conv, with: newMessages)
            }

        case .deleteConversation(let convId):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.deleteConversation(conv)
            }

        case .notify(let title, let body):
            NotificationManager.showCustomNotification(title: title, body: body)

        case .clipboard(let text):
            UIPasteboard.general.string = text

        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .haptic(let style):
            let generator: UIImpactFeedbackGenerator
            switch style {
            case "light": generator = UIImpactFeedbackGenerator(style: .light)
            case "heavy": generator = UIImpactFeedbackGenerator(style: .heavy)
            case "rigid": generator = UIImpactFeedbackGenerator(style: .rigid)
            case "soft": generator = UIImpactFeedbackGenerator(style: .soft)
            default: generator = UIImpactFeedbackGenerator(style: .medium)
            }
            generator.impactOccurred()

        case .speak(let text):
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            AVSpeechSynthesizer().speak(utterance)

        case .switchConversation(let convId):
            if let conv = conversationStore.findConversation(withId: convId) {
                conversationStore.selectConversation(conv)
            }

        case .question(let questions, let convId):
            if let convId = convId {
                conversationStore.pendingQuestion = PendingQuestion(conversationId: convId, questions: questions)
            } else if let currentId = conversationStore.currentConversation?.id {
                conversationStore.pendingQuestion = PendingQuestion(conversationId: currentId, questions: questions)
            }

        case .screenshot(let convId):
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let image = renderer.image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }

                guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }
                let base64 = jpegData.base64EncodedString()

                let targetConvId = convId ?? conversationStore.currentConversation?.id
                guard let targetConvId else { return }
                guard let conv = conversationStore.findConversation(withId: targetConvId) else { return }

                let userMessage = ChatMessage(isUser: true, text: "[screenshot]", imageBase64: base64)
                conversationStore.addMessage(userMessage, to: conv)

                connection.sendChat(
                    "[screenshot]",
                    workingDirectory: conv.workingDirectory,
                    sessionId: conv.sessionId,
                    isNewSession: false,
                    conversationId: targetConvId,
                    imagesBase64: [base64],
                    conversationName: conv.name,
                    conversationSymbol: conv.symbol
                )
            }

        case .conversationOutputStarted(let convId):
            if let window = windowManager.windowForConversation(convId),
               window.id != windowManager.activeWindowId {
                windowManager.markUnread(window.id)
            }

        default:
            break
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

        connection.connect(host: host, port: port, token: token)
    }

}
