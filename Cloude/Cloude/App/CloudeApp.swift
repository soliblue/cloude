import SwiftUI
import UIKit

@main
struct CloudeApp: App {
    @StateObject private var connection = ConnectionManager()
    @StateObject private var projectStore = ProjectStore()
    @State private var showSettings = false
    @State private var showFileBrowser = false
    @State private var showProjects = false
    @State private var showSplitView = false
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
            VStack(spacing: 0) {
                if projectStore.currentConversation != nil && !showSplitView {
                    titleHeader
                }
                Group {
                    if showSplitView {
                        SplitChatView(connection: connection, projectStore: projectStore)
                    } else {
                        ProjectChatView(connection: connection, store: projectStore)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 16) {
                            Button(action: { showProjects = true }) {
                                Image(systemName: "folder")
                                    .padding(4)
                            }

                            Button(action: { newConversation() }) {
                                Image(systemName: "square.and.pencil")
                                    .padding(4)
                            }
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
                        HStack(spacing: 16) {
                            Button(action: { showSplitView.toggle() }) {
                                Image(systemName: showSplitView ? "rectangle" : "rectangle.split.2x2")
                                    .padding(4)
                            }

                            Button(action: { showFileBrowser = true }) {
                                Image(systemName: "doc.text")
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
            SettingsView(connection: connection)
        }
        .sheet(isPresented: $showFileBrowser) {
            NavigationStack {
                FileBrowserView(connection: connection)
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showFileBrowser = false }
                        }
                    }
            }
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
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var titleHeader: some View {
        HStack {
            if let project = projectStore.currentProject {
                Text(project.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("›")
                    .foregroundColor(.secondary)
            }
            Text(projectStore.currentConversation?.name ?? "")
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func newConversation() {
        if let project = projectStore.currentProject {
            _ = projectStore.newConversation(in: project)
        } else {
            let project = projectStore.createProject(name: "Default Project")
            _ = projectStore.newConversation(in: project)
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

        connection.connect(host: host, port: port, token: token)
    }
}
