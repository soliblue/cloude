import SwiftUI
import UIKit

@main
struct CloudeApp: App {
    @StateObject private var connection = ConnectionManager()
    @StateObject private var projectStore = ProjectStore()
    @State private var showSettings = false
    @State private var showProjects = false
    @State private var wasBackgrounded = false
    @State private var lastActiveSessionId: String? = nil
    @State private var isUnlocked = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            if requireBiometricAuth && !isUnlocked {
                LockScreenView(onUnlock: { isUnlocked = true })
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        NavigationStack {
            SplitChatView(connection: connection, projectStore: projectStore)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showProjects = true }) {
                            Image(systemName: "folder")
                                .padding(4)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        ZStack {
                            HStack {
                                Spacer()
                                Image("Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
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
        .sheet(isPresented: $showProjects) {
            ProjectNavigationView(store: projectStore, connection: connection, isPresented: $showProjects)
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
        .preferredColorScheme(appTheme.colorScheme)
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

        connection.connect(host: host, port: port, token: token)
    }
}
