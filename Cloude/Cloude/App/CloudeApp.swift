import SwiftUI
import CloudeShared

@main
struct CloudeApp: App {
    @StateObject private var connection = ConnectionManager()
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var windowManager = WindowManager()
    @StateObject private var heartbeatStore = HeartbeatStore()
    @State private var showSettings = false
    @State private var showHeartbeat = false
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
            SplitChatView(connection: connection, projectStore: projectStore, windowManager: windowManager)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 12) {
                            HeartbeatButton(unreadCount: heartbeatStore.unreadCount) {
                                showHeartbeat = true
                            }
                            Button(action: {
                                isLoadingMemories = true
                                memorySections = []
                                connection.send(.getMemories)
                                showMemories = true
                            }) {
                                Image(systemName: "brain")
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: { windowManager.toggleLayoutMode() }) {
                                Image(systemName: windowManager.layoutMode == .paged ? "rectangle.split.1x2" : "rectangle.stack")
                                    .padding(4)
                            }
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                                    .padding(4)
                            }
                        }
                    }
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connection: connection, windowManager: windowManager)
        }
        .sheet(isPresented: $showHeartbeat) {
            HeartbeatSheet(heartbeatStore: heartbeatStore, connection: connection)
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

        connection.onMissedResponse = { [projectStore] _, text, _ in
            if let project = projectStore.currentProject,
               let conversation = projectStore.currentConversation {
                let message = ChatMessage(isUser: false, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
                projectStore.addMessage(message, to: conversation, in: project)
            }
        }

        connection.onDisconnect = { [projectStore] convId, output in
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
                    output.reset()
                    break
                }
            }
        }

        connection.onHeartbeatConfig = { [heartbeatStore] intervalMinutes, unreadCount, sessionId in
            heartbeatStore.handleConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount, sessionId: sessionId)
        }

        connection.onHeartbeatOutput = { [heartbeatStore] text in
            heartbeatStore.handleOutput(text: text)
        }

        connection.onHeartbeatComplete = { [heartbeatStore] message in
            heartbeatStore.handleComplete(message: message)
        }

        connection.onMemories = { sections in
            memorySections = sections
            isLoadingMemories = false
        }

        connection.connect(host: host, port: port, token: token)
    }
}
