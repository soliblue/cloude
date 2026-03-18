import SwiftUI
import Combine
import CloudeShared
import UIKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@main
struct CloudeApp: App {
    @StateObject var connection = ConnectionManager()
    @StateObject var conversationStore = ConversationStore()
    @StateObject var windowManager = WindowManager()
    @StateObject var environmentStore = EnvironmentStore()
    @State private var showSettings = false
    @State private var showMemories = false
    @State var memorySections: [MemorySection] = []
    @State var isLoadingMemories = false
    @State var memoriesFromCache = false
    @State private var showPlans = false
    @State var planStages: [String: [PlanItem]] = [:]
    @State var isLoadingPlans = false
    @State var plansFromCache = false
    @State private var wasBackgrounded = false
    @State private var lastActiveSessionId: String? = nil
    @State private var isUnlocked = false
    @State private var filePathToPreview: String? = nil
    @State private var filePreviewEnvironmentId: UUID? = nil
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.vanGogh.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .vanGogh }
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @AppStorage("debugOverlayEnabled") private var debugOverlayEnabled = false
    @ObservedObject private var debugMetrics = DebugMetrics.shared
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
            .overlay { FullscreenColorOverlay() }
            .overlay {
                if debugOverlayEnabled {
                    DebugOverlayView(metrics: debugMetrics)
                }
            }
            .environmentObject(connection)
            .environment(\.appTheme, appTheme)
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
                .toolbarBackground(Color.themeSecondary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showSettings = true }) {
                            ConnectionStatusLogo(connection: connection)
                        }
                        .buttonStyle(.borderless)
                    }
                    ToolbarItem(placement: .principal) {
                        environmentIndicators
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
                    let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
                    if connection.connection(for: envId)?.isAuthenticated == true {
                        showPlans = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            filePreviewEnvironmentId = envId
                            filePathToPreview = path
                        }
                    }
                }
            )
        }
        .sheet(item: $filePathToPreview) { path in
            FilePreviewView(path: path, connection: connection, environmentId: filePreviewEnvironmentId)
        }
        .onOpenURL { url in
            guard url.scheme == "cloude" else { return }
            switch url.host {
            case "file":
                let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
                if connection.connection(for: envId)?.isAuthenticated == true {
                    filePreviewEnvironmentId = envId
                    filePathToPreview = url.path.removingPercentEncoding ?? url.path
                }
            case "memory":
                openMemories()
            default:
                break
            }
        }
        .onAppear {
            loadAndConnect()
            if debugOverlayEnabled { debugMetrics.start(observing: connection.objectWillChange) }
        }
        .onChange(of: debugOverlayEnabled) { _, enabled in
            if enabled { debugMetrics.start(observing: connection.objectWillChange) } else { debugMetrics.stop() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                wasBackgrounded = true
                lastActiveSessionId = windowManager.activeWindow?.conversation(in: conversationStore)?.sessionId
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

    @ViewBuilder
    private var environmentIndicators: some View {
        VStack(spacing: 4) {
            if environmentStore.environments.count > 1 {
                HStack(spacing: 8) {
                    ForEach(environmentStore.environments) { env in
                        let conn = connection.connection(for: env.id)
                        let isAuthenticated = conn?.isAuthenticated ?? false
                        let isConnecting = (conn?.isConnected ?? false) && !isAuthenticated

                        Button(action: {
                            if isAuthenticated || isConnecting {
                                connection.disconnectEnvironment(env.id, clearCredentials: false)
                            } else {
                                connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                            }
                        }) {
                            Image(systemName: env.symbol)
                                .font(.system(size: 11, weight: isAuthenticated ? .semibold : .regular))
                                .foregroundColor(isAuthenticated || isConnecting ? .accentColor : .secondary.opacity(0.4))
                                .modifier(StreamingPulseModifier(isStreaming: isConnecting))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            navTitlePill
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
                        Text("- \(folder)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let conv = conversation, conv.totalCost > 0 {
                        Text("- $\(String(format: "%.2f", conv.totalCost))")
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
        if let wd = windowManager.activeWindow?.conversation(in: conversationStore)?.workingDirectory ?? activeEnvConn?.defaultWorkingDirectory {
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
            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
        }
    }

}
