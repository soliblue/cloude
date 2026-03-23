import SwiftUI
import Combine
import CloudeShared

extension CloudeApp {
    var mainContent: some View {
        NavigationStack {
            MainChatView(
                connection: connection,
                conversationStore: conversationStore,
                windowManager: windowManager,
                environmentStore: environmentStore,
                onShowPlans: { openPlans() },
                onShowMemories: { openMemories() },
                onShowSettings: { showSettings = true },
                onShowWhiteboard: {
                    whiteboardStore.load(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
                    showWhiteboard = true
                }
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
                        navTitlePill
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            if let window = windowManager.activeWindow {
                                windowManager.setActive(window.id)
                                windowManager.removeWindow(window.id)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
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
        .fullScreenCover(isPresented: $showWhiteboard) {
            WhiteboardSheet(store: whiteboardStore)
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
}
