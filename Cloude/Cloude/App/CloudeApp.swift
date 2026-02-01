import SwiftUI
import Combine
import CloudeShared

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

        connection.onMissedResponse = { [projectStore] _, text, _, interruptedConvId, interruptedMsgId in
            if let convId = interruptedConvId,
               let msgId = interruptedMsgId,
               let project = projectStore.projects.first(where: { $0.conversations.contains { $0.id == convId } }),
               let conversation = project.conversations.first(where: { $0.id == convId }) {
                projectStore.updateMessage(msgId, in: conversation, in: project) { msg in
                    msg.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    msg.wasInterrupted = false
                }
                projectStore.objectWillChange.send()
            } else if let project = projectStore.currentProject,
                      let conversation = projectStore.currentConversation {
                let message = ChatMessage(isUser: false, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
                projectStore.addMessage(message, to: conversation, in: project)
            }
        }

        connection.onDisconnect = { [projectStore, connection] convId, output in
            guard !output.text.isEmpty else { return }
            for project in projectStore.projects {
                if let conv = project.conversations.first(where: { $0.id == convId }) {
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
                    break
                }
            }
        }

        connection.onMemories = { sections in
            memorySections = sections
            isLoadingMemories = false
        }

        connection.onRenameConversation = { [projectStore] convId, name in
            for project in projectStore.projects {
                if let conv = project.conversations.first(where: { $0.id == convId }) {
                    projectStore.renameConversation(conv, in: project, to: name)
                    break
                }
            }
        }

        connection.onSetConversationSymbol = { [projectStore] convId, symbol in
            for project in projectStore.projects {
                if let conv = project.conversations.first(where: { $0.id == convId }) {
                    projectStore.setConversationSymbol(conv, in: project, symbol: symbol)
                    break
                }
            }
        }

        connection.onSessionIdReceived = { [projectStore] convId, sessionId in
            for project in projectStore.projects {
                if let conv = project.conversations.first(where: { $0.id == convId }) {
                    projectStore.updateSessionId(conv, in: project, sessionId: sessionId)
                    break
                }
            }
        }

        connection.onHistorySync = { [projectStore] sessionId, historyMessages in
            for project in projectStore.projects {
                if let conv = project.conversations.first(where: { $0.sessionId == sessionId }) {
                    let newMessages = historyMessages.map { msg in
                        ChatMessage(isUser: msg.isUser, text: msg.text)
                    }
                    projectStore.replaceMessages(conv, in: project, with: newMessages)
                    break
                }
            }
        }

        connection.connect(host: host, port: port, token: token)
    }
}
