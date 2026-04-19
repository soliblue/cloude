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
                onShowSettings: { settingsStore.isPresented = true },
                onShowWhiteboard: {
                    whiteboardStore.present(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
                }
            )
            .agenticID("main_chat_view")
            .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.themeBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { settingsStore.isPresented = true }) {
                            SettingsButton()
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
                        WindowCloseButton(action: closeOrResetActiveWindow)
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
        .fullScreenCover(isPresented: $whiteboardStore.isPresented) {
            WhiteboardSheet(
                store: whiteboardStore,
                onSendSnapshot: {
                    handleWhiteboardAction(action: .snapshot, json: [:], conversationId: nil)
                },
                isConnected: connection.connection(for: windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId)?.phase == .authenticated
            )
            .agenticID("whiteboard_sheet")
        }
        .sheet(item: $filePathToPreview) { path in
            FilePreviewView(path: path, connection: connection, environmentId: filePreviewEnvironmentId)
                .agenticID("file_preview_sheet")
        }
        .sheet(item: $gitDiffRequest) { request in
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
