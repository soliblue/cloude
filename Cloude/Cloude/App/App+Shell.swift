import SwiftUI
import Combine
import CloudeShared

extension App {
    var shell: some View {
        NavigationStack {
            WorkspaceView(
                conversationStore: conversationStore,
                windowManager: windowManager,
                environmentStore: environmentStore,
                onShowSettings: { settingsStore.isPresented = true },
                onSendMessage: { sendActiveConversationMessage(onShowSettings: { settingsStore.isPresented = true }) },
                onStopActiveConversation: stopActiveConversationRun,
                onRefreshConversation: refreshConversation(for:),
                onSelectConversationForEditing: { window, conversation in
                    selectConversationForEditing(conversation, in: window)
                },
                onRefreshEditingWindowConversation: refreshEditingConversation(for:),
                onDuplicateEditingConversation: { window, conversation in
                    duplicateEditingConversation(conversation, in: window)
                },
                onSelectConversationFromSearch: selectConversationFromSearch(_:)
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
                                .runtimeContext(conversationStore: conversationStore, environmentStore: environmentStore)
                                .symbol
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
        .onReceive(environmentStore.connectionStore.events, perform: handleConnectionEvent)
        .sheet(isPresented: $settingsStore.isPresented) {
            SettingsView(environmentStore: environmentStore)
                .agenticID("settings_sheet")
        }
        .sheet(item: $filePathToPreview) { path in
            FilePreviewView(path: path, environmentStore: environmentStore, environmentId: filePreviewEnvironmentId)
                .agenticID("file_preview_sheet")
        }
        .sheet(item: $gitDiffRequest) { request in
            GitDiffView(environmentStore: environmentStore, repoPath: request.repoPath, file: request.file, environmentId: request.environmentId)
                .agenticID("git_diff_sheet")
        }
        .onOpenURL(perform: handleDeepLink)
        .onAppear {
            AppLogger.bootstrapInfo("shell onAppear")
            loadAndConnect()
            if debugOverlayEnabled { debugMetrics.start(observing: environmentStore.objectWillChange) }
        }
        .onChange(of: debugOverlayEnabled) { _, enabled in
            if enabled { debugMetrics.start(observing: environmentStore.objectWillChange) } else { debugMetrics.stop() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            importLatestScreenshot(conversationId: activeConversation()?.id)
        }
    }
}
