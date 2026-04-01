import SwiftUI
import Combine
import CloudeShared

extension App {
    var shell: some View {
        NavigationStack {
            WorkspaceView(
                connection: connection,
                conversationStore: conversationStore,
                windowManager: windowManager,
                environmentStore: environmentStore,
                onShowPlans: {
                    plansStore.open(
                        connection: connection,
                        windowManager: windowManager,
                        conversationStore: conversationStore,
                        environmentStore: environmentStore
                    )
                },
                onShowMemories: {
                    memoriesStore.open(connection: connection)
                },
                onShowSettings: { settingsStore.isPresented = true },
                onShowWhiteboard: {
                    whiteboardStore.present(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
                }
            )
            .agenticID("main_chat_view")
            .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.themeSecondary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { settingsStore.isPresented = true }) {
                            SettingsButton(connection: connection)
                        }
                        .agenticID("toolbar_settings_button")
                        .buttonStyle(.borderless)
                    }
                    ToolbarItem(placement: .principal) {
                        WindowTitlePill(
                            symbol: windowManager.activeWindow?
                                .conversation(in: conversationStore)?
                                .environmentId
                                .flatMap { envId in
                                    environmentStore.environments.first { $0.id == envId }?.symbol
                                }
                        )
                            .agenticID("toolbar_title")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: closeOrResetActiveWindow) {
                            Image(systemName: "xmark")
                                .font(.system(size: DS.Icon.m, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .agenticID("toolbar_close_window_button")
                        .buttonStyle(.borderless)
                    }
                }
        }
        .onReceive(connection.events, perform: handleConnectionEvent)
        .onReceive(NotificationCenter.default.publisher(for: .openWhiteboard)) { _ in
            whiteboardStore.present(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
        }
        .sheet(isPresented: $settingsStore.isPresented) {
            SettingsView(connection: connection, environmentStore: environmentStore)
                .agenticID("settings_sheet")
        }
        .sheet(isPresented: $memoriesStore.isPresented) {
            MemoriesSheet(sections: memoriesStore.sections, isLoading: memoriesStore.isLoading, fromCache: memoriesStore.fromCache)
                .agenticID("memories_sheet")
        }
        .sheet(isPresented: $plansStore.isPresented) {
            PlansSheet(
                stages: plansStore.stages,
                isLoading: plansStore.isLoading,
                fromCache: plansStore.fromCache,
                initialStage: plansStore.initialStage,
                onOpenFile: { path in
                    let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
                    if connection.connection(for: envId)?.isAuthenticated == true {
                        plansStore.isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + DS.Duration.m) {
                            filePreviewEnvironmentId = envId
                            filePathToPreview = path
                        }
                    }
                }
            )
            .agenticID("plans_sheet")
        }
        .fullScreenCover(isPresented: $whiteboardStore.isPresented) {
            WhiteboardSheet(
                store: whiteboardStore,
                onSendSnapshot: {
                    handleWhiteboardAction(action: "snapshot", json: [:], conversationId: nil)
                },
                isConnected: {
                    let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
                    return connection.connection(for: envId)?.isAuthenticated ?? false
                }()
            )
            .agenticID("whiteboard_sheet")
        }
        .sheet(item: $filePathToPreview, onDismiss: {
            NotificationCenter.default.post(name: .refreshActiveChatView, object: nil)
        }) { path in
            FilePreviewView(path: path, connection: connection, environmentId: filePreviewEnvironmentId)
                .agenticID("file_preview_sheet")
        }
        .sheet(item: $gitDiffRequest, onDismiss: {
            NotificationCenter.default.post(name: .refreshActiveChatView, object: nil)
        }) { request in
            GitDiffView(connection: connection, repoPath: request.repoPath, file: request.file, environmentId: request.environmentId)
                .agenticID("git_diff_sheet")
        }
        .onOpenURL(perform: handleDeepLink)
        .onAppear {
            AppLogger.bootstrapInfo("shell onAppear")
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

                connection.beginBackgroundStreamingIfNeeded()
            } else if newPhase == .active {
                connection.endBackgroundStreaming()
                if wasBackgrounded {
                    connection.handleForegroundTransition()
                } else {
                    connection.reconnectAll()
                }
                wasBackgrounded = false
            }
        }
    }
}
