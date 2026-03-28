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
                fileBrowserRootOverrides: fileBrowserRootOverrides,
                gitRepoRootOverrides: gitRepoRootOverrides,
                onShowPlans: { openPlans() },
                onShowMemories: { openMemories() },
                onShowSettings: { showSettings = true },
                onShowWhiteboard: {
                    whiteboardStore.load(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
                    showWhiteboard = true
                }
            )
            .agenticID("main_chat_view")
            .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.themeSecondary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showSettings = true }) {
                            ConnectionStatusLogo(connection: connection)
                        }
                        .agenticID("toolbar_settings_button")
                        .buttonStyle(.borderless)
                    }
                    ToolbarItem(placement: .principal) {
                        navTitlePill
                            .agenticID("toolbar_title")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            if let window = windowManager.activeWindow {
                                windowManager.setActive(window.id)
                                windowManager.removeWindow(window.id)
                            }
                        }) {
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
            whiteboardStore.load(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
            showWhiteboard = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connection: connection, environmentStore: environmentStore)
                .agenticID("settings_sheet")
        }
        .sheet(isPresented: $showMemories) {
            MemoriesSheet(sections: memorySections, isLoading: isLoadingMemories, fromCache: memoriesFromCache)
                .agenticID("memories_sheet")
        }
        .sheet(isPresented: $showPlans) {
            PlansSheet(
                stages: planStages,
                isLoading: isLoadingPlans,
                fromCache: plansFromCache,
                initialStage: initialPlanStage,
                onOpenFile: { path in
                    let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
                    if connection.connection(for: envId)?.isAuthenticated == true {
                        showPlans = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + DS.Duration.m) {
                            filePreviewEnvironmentId = envId
                            filePathToPreview = path
                        }
                    }
                }
            )
            .agenticID("plans_sheet")
        }
        .fullScreenCover(isPresented: $showWhiteboard) {
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
            AppLogger.bootstrapInfo("mainContent onAppear")
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
