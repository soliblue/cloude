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
    @StateObject private var environmentStore = EnvironmentStore()
    @State private var showSettings = false
    @State private var showMemories = false
    @State private var memorySections: [MemorySection] = []
    @State private var isLoadingMemories = false
    @State private var memoriesFromCache = false
    @State private var showPlans = false
    @State private var planStages: [String: [PlanItem]] = [:]
    @State private var isLoadingPlans = false
    @State private var plansFromCache = false
    @State private var showScheduledTasks = false
    @State private var scheduledTasks: [ScheduledTask] = []
    @State private var isLoadingScheduledTasks = false
    @State private var wasBackgrounded = false
    @State private var lastActiveSessionId: String? = nil
    @State private var isUnlocked = false
    @State private var filePathToPreview: String? = nil
    @State private var filePreviewEnvironmentId: UUID? = nil
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.oceanDark.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .oceanDark }
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
            .environmentObject(connection)
            .preferredColorScheme(appTheme.colorScheme)
        }
    }

    private var mainContent: some View {
        NavigationStack {
            MainChatView(
                connection: connection,
                conversationStore: conversationStore,
                windowManager: windowManager,
                environmentStore: environmentStore,
                onShowPlans: { openPlans() },
                onShowMemories: { openMemories() },
                onShowSettings: { showSettings = true }
            )
            .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showSettings = true }) {
                            ConnectionStatusLogo(connection: connection)
                        }
                        .buttonStyle(.borderless)
                    }
                    ToolbarItem(placement: .principal) {
                        navTitlePill
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            if connection.isAuthenticated || connection.isConnected {
                                connection.disconnectAll(clearCredentials: false)
                            } else {
                                connectAllConfiguredEnvironments()
                            }
                        }) {
                            Image(systemName: "power")
                                .foregroundStyle(connection.isAuthenticated || connection.isConnected ? Color.accentColor : .secondary)
                        }
                        .simultaneousGesture(LongPressGesture().onEnded { _ in showSettings = true })
                        .padding(.horizontal, 8)
                    }
                }
        }
        .onReceive(connection.events, perform: handleConnectionEvent)
        .sheet(isPresented: $showSettings) {
            SettingsView(connection: connection, environmentStore: environmentStore)
        }
        .sheet(isPresented: $showMemories) {
            MemoriesSheet(sections: memorySections, isLoading: isLoadingMemories, fromCache: memoriesFromCache)
        }
        .sheet(isPresented: $showPlans) {
            PlansSheet(
                stages: planStages,
                isLoading: isLoadingPlans,
                fromCache: plansFromCache,
                onOpenFile: { path in
                    showPlans = false
                    let envId = conversationStore.currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        filePreviewEnvironmentId = envId
                        filePathToPreview = path
                    }
                }
            )
        }
        .sheet(isPresented: $showScheduledTasks) {
            ScheduledTasksSheet(
                tasks: $scheduledTasks,
                isLoading: isLoadingScheduledTasks,
                connection: connection,
                conversationStore: conversationStore,
                windowManager: windowManager,
                onOpenConversation: { showScheduledTasks = false }
            )
        }
        .sheet(item: $filePathToPreview) { path in
            FilePreviewView(path: path, connection: connection, environmentId: filePreviewEnvironmentId)
        }
        .onOpenURL { url in
            guard url.scheme == "cloude" else { return }
            switch url.host {
            case "file":
                let path = url.path.removingPercentEncoding ?? url.path
                filePreviewEnvironmentId = conversationStore.currentConversation?.environmentId
                filePathToPreview = path
            case "memory":
                openMemories()
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
                connection.reconnectAll()
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
                if let sessionId = output.newSessionId,
                   let envConn = connection.connectionForConversation(convId) {
                    envConn.interruptedSession = (convId, sessionId, message.id)
                }
                output.reset()
            }

        case .memories(let sections):
            memorySections = sections
            memoriesFromCache = false
            isLoadingMemories = false
            OfflineCacheService.saveMemories(sections)

        case .plans(let stages):
            planStages = stages
            plansFromCache = false
            isLoadingPlans = false
            OfflineCacheService.savePlans(stages)

        case .planDeleted(let stage, let filename):
            planStages[stage]?.removeAll { $0.filename == filename }

        case .scheduledTasks(let tasks):
            scheduledTasks = tasks
            isLoadingScheduledTasks = false

        case .scheduledTaskUpdated(let task):
            if let idx = scheduledTasks.firstIndex(where: { $0.id == task.id }) {
                scheduledTasks[idx] = task
            } else {
                scheduledTasks.append(task)
            }

        case .scheduledTaskDeleted(let taskId):
            scheduledTasks.removeAll { $0.id == taskId }

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

    @ViewBuilder
    private var navTitlePill: some View {
        if !windowManager.isHeartbeatShowing {
            let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
            Button(action: {
                NotificationCenter.default.post(name: .editActiveWindow, object: nil)
            }) {
                HStack(spacing: 5) {
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: conv.name)
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
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func openMemories() {
        if let cached = OfflineCacheService.loadMemories() {
            memorySections = cached.sections
            memoriesFromCache = true
            isLoadingMemories = connection.isAuthenticated
        } else {
            memorySections = []
            memoriesFromCache = false
            isLoadingMemories = true
        }
        if connection.isAuthenticated {
            connection.send(.getMemories)
        }
        showMemories = true
    }

    private func openPlans() {
        if let cached = OfflineCacheService.loadPlans() {
            planStages = cached.stages
            plansFromCache = true
            isLoadingPlans = connection.isAuthenticated
        } else {
            planStages = [:]
            plansFromCache = false
            isLoadingPlans = true
        }
        let activeEnvConn = connection.connection(for: environmentStore.activeEnvironmentId)
        if let wd = conversationStore.currentConversation?.workingDirectory ?? activeEnvConn?.defaultWorkingDirectory {
            connection.getPlans(workingDirectory: wd)
        }
        showPlans = true
    }

    private func loadAndConnect() {
        NotificationManager.requestPermission()

        if environmentStore.environments.allSatisfy({ $0.host.isEmpty || $0.token.isEmpty }) {
            showSettings = true
        }
    }

    private func connectAllConfiguredEnvironments() {
        for env in environmentStore.environments where !env.host.isEmpty && !env.token.isEmpty {
            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token)
        }
    }

}
