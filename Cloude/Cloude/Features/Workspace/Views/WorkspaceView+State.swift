import SwiftUI
import CloudeShared

extension WorkspaceView {
    var currentConversation: Conversation? {
        store.currentConversation(windowManager: windowManager, conversationStore: conversationStore)
    }

    var activeEnvConnection: EnvironmentConnection? {
        store.activeEnvConnection(
            connection: connection,
            windowManager: windowManager,
            conversationStore: conversationStore,
            environmentStore: environmentStore
        )
    }

    var hasEnvironmentMismatch: Bool {
        store.hasEnvironmentMismatch(connection: connection, windowManager: windowManager, conversationStore: conversationStore)
    }

    var activeConversationIsRunning: Bool {
        store.activeConversationIsRunning(connection: connection, windowManager: windowManager)
    }

    var currentPageIndexBinding: Binding<Int> {
        Binding(get: { store.currentPageIndex }, set: { store.currentPageIndex = $0 })
    }

    var editingWindowBinding: Binding<Window?> {
        Binding(get: { store.editingWindow }, set: { store.editingWindow = $0 })
    }

    var showConversationSearchBinding: Binding<Bool> {
        Binding(get: { store.showConversationSearch }, set: { store.showConversationSearch = $0 })
    }

    var showUsageStatsBinding: Binding<Bool> {
        Binding(get: { store.showUsageStats }, set: { store.showUsageStats = $0 })
    }

    var inputTextBinding: Binding<String> {
        Binding(get: { store.inputText }, set: { store.inputText = $0 })
    }

    var attachedImagesBinding: Binding<[AttachedImage]> {
        Binding(get: { store.attachedImages }, set: { store.attachedImages = $0 })
    }

    var attachedFilesBinding: Binding<[AttachedFile]> {
        Binding(get: { store.attachedFiles }, set: { store.attachedFiles = $0 })
    }

    var currentEffortBinding: Binding<EffortLevel?> {
        Binding(get: { store.currentEffort }, set: { store.currentEffort = $0 })
    }

    var currentModelBinding: Binding<ModelSelection?> {
        Binding(get: { store.currentModel }, set: { store.currentModel = $0 })
    }

    var editingWindow: Window? {
        get { store.editingWindow }
        nonmutating set { store.editingWindow = newValue }
    }

    var currentPageIndex: Int {
        get { store.currentPageIndex }
        nonmutating set { store.currentPageIndex = newValue }
    }

    var isKeyboardVisible: Bool {
        get { store.isKeyboardVisible }
        nonmutating set { store.isKeyboardVisible = newValue }
    }

    var inputText: String {
        get { store.inputText }
        nonmutating set { store.inputText = newValue }
    }

    var attachedImages: [AttachedImage] {
        get { store.attachedImages }
        nonmutating set { store.attachedImages = newValue }
    }

    var attachedFiles: [AttachedFile] {
        get { store.attachedFiles }
        nonmutating set { store.attachedFiles = newValue }
    }

    var drafts: [UUID: (text: String, images: [AttachedImage], effort: EffortLevel?, model: ModelSelection?)] {
        get { store.drafts }
        nonmutating set { store.drafts = newValue }
    }

    var gitBranches: [String: String] {
        get { store.gitBranches }
        nonmutating set { store.gitBranches = newValue }
    }

    var gitStats: [String: (additions: Int, deletions: Int)] {
        get { store.gitStats }
        nonmutating set { store.gitStats = newValue }
    }

    var pendingGitChecks: [(path: String, environmentId: UUID?)] {
        get { store.pendingGitChecks }
        nonmutating set { store.pendingGitChecks = newValue }
    }

    var fileSearchResults: [String] {
        get { store.fileSearchResults }
        nonmutating set { store.fileSearchResults = newValue }
    }

    var currentEffort: EffortLevel? {
        get { store.currentEffort }
        nonmutating set { store.currentEffort = newValue }
    }

    var currentModel: ModelSelection? {
        get { store.currentModel }
        nonmutating set { store.currentModel = newValue }
    }

    var showConversationSearch: Bool {
        get { store.showConversationSearch }
        nonmutating set { store.showConversationSearch = newValue }
    }

    var showUsageStats: Bool {
        get { store.showUsageStats }
        nonmutating set { store.showUsageStats = newValue }
    }

    var usageStats: UsageStats? {
        get { store.usageStats }
        nonmutating set { store.usageStats = newValue }
    }

    var awaitingUsageStats: Bool {
        get { store.awaitingUsageStats }
        nonmutating set { store.awaitingUsageStats = newValue }
    }

    var refreshingSessionIds: Set<String> {
        get { store.refreshingSessionIds }
        nonmutating set { store.refreshingSessionIds = newValue }
    }

    var refreshTrigger: Bool {
        get { store.refreshTrigger }
        nonmutating set { store.refreshTrigger = newValue }
    }

    var exportCopied: Bool {
        get { store.exportCopied }
        nonmutating set { store.exportCopied = newValue }
    }
}
