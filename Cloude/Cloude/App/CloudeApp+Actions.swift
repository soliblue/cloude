import SwiftUI
import CloudeShared
import OSLog
import Foundation

extension Notification.Name {
    static let openConversationSearch = Notification.Name("openConversationSearch")
    static let requestUsageStats = Notification.Name("requestUsageStats")
    static let refreshActiveChatView = Notification.Name("refreshActiveChatView")
}

extension CloudeApp {
    func dismissTransientUI() {
        showSettings = false
        showMemories = false
        showPlans = false
        showWhiteboard = false
        filePathToPreview = nil
        gitDiffRequest = nil
    }

    func activeConversation() -> Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    func selectConversation(id: UUID) {
        guard let conversation = conversationStore.conversation(withId: id) else {
            AppLogger.bootstrapInfo("select conversation failed convId=\(id.uuidString)")
            return
        }
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        AppLogger.bootstrapInfo("selected conversation convId=\(id.uuidString) windowId=\(activeWindow.id.uuidString)")
    }

    func openMemories() {
        AppLogger.beginInterval("memories.open")
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

    func openPlans() {
        AppLogger.beginInterval("plans.open")
        let activeEnvConn = connection.connection(for: environmentStore.activeEnvironmentId)
        let wd = windowManager.activeWindow?.conversation(in: conversationStore)?.workingDirectory ?? activeEnvConn?.defaultWorkingDirectory ?? connection.defaultWorkingDirectory
        if let cached = OfflineCacheService.loadPlans() {
            planStages = cached.stages
            plansFromCache = true
            isLoadingPlans = connection.isAuthenticated && wd != nil
        } else {
            planStages = [:]
            plansFromCache = false
            isLoadingPlans = wd != nil
        }
        if let wd {
            connection.getPlans(workingDirectory: wd, environmentId: environmentStore.activeEnvironmentId)
        }
        showPlans = true
    }

    func loadAndConnect() {
        NotificationManager.requestPermission()
        AppLogger.bootstrapInfo("loadAndConnect start envs=\(environmentStore.environments.count)")
        #if DEBUG
        DebugMetrics.log("Bootstrap", "loadAndConnect start envs=\(environmentStore.environments.count)")
        #endif

        let processEnvironment = ProcessInfo.processInfo.environment
        if let host = processEnvironment["CLOUDE_SIM_HOST"],
           let token = processEnvironment["CLOUDE_SIM_TOKEN"],
           !host.isEmpty,
           !token.isEmpty {
            let port = UInt16(processEnvironment["CLOUDE_SIM_PORT"] ?? "") ?? 8765
            let symbol = processEnvironment["CLOUDE_SIM_SYMBOL"] ?? "desktopcomputer"
            let environment = environmentStore.upsertEnvironment(host: host, port: port, token: token, symbol: symbol)
            AppLogger.bootstrapInfo("launch env host=\(host):\(port) envId=\(environment.id.uuidString)")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "launch env host=\(host):\(port) envId=\(environment.id.uuidString.prefix(6))")
            #endif
            connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
            return
        }

        if let environment = environmentStore.activeEnvironment,
           !environment.host.isEmpty,
           !environment.token.isEmpty {
            AppLogger.bootstrapInfo("saved env host=\(environment.host):\(environment.port) envId=\(environment.id.uuidString)")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "saved env host=\(environment.host):\(environment.port) envId=\(environment.id.uuidString.prefix(6))")
            #endif
            connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
            return
        }

        if environmentStore.environments.allSatisfy({ $0.host.isEmpty || $0.token.isEmpty }) {
            AppLogger.bootstrapInfo("no configured environment, opening settings")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "no configured environment, opening settings")
            #endif
            showSettings = true
        }
    }

    func connectAllConfiguredEnvironments() {
        for env in environmentStore.environments where !env.host.isEmpty && !env.token.isEmpty {
            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
        }
    }

    func openUsageStats() {
        AppLogger.beginInterval("usage.open")
        NotificationCenter.default.post(name: .requestUsageStats, object: nil)
        AppLogger.bootstrapInfo("open usage stats requested")
    }

    func openConversationSearch(query: String? = nil) {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedQuery.isEmpty else {
            NotificationCenter.default.post(name: .openConversationSearch, object: nil)
            AppLogger.bootstrapInfo("open conversation search")
            return
        }

        let lowercasedQuery = trimmedQuery.lowercased()
        let conversation = conversationStore.listableConversations.sorted { $0.lastMessageAt > $1.lastMessageAt }.first { conv in
            conv.id.uuidString.lowercased().contains(lowercasedQuery) ||
            conv.name.lowercased().contains(lowercasedQuery) ||
            (conv.workingDirectory?.lowercased().contains(lowercasedQuery) ?? false) ||
            conv.messages.contains { $0.text.lowercased().contains(lowercasedQuery) }
        }

        guard let conversation else {
            NotificationCenter.default.post(name: .openConversationSearch, object: nil)
            AppLogger.bootstrapInfo("conversation search no match query=\(trimmedQuery)")
            return
        }

        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        if let activeWindow = windowManager.activeWindow {
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo("conversation search selected convId=\(conversation.id.uuidString) query=\(trimmedQuery)")
        }
    }

    func createNewConversation(path: String? = nil) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        let workingDirectory = path?.nilIfEmpty
        let conversation = conversationStore.newConversation(
            workingDirectory: workingDirectory,
            environmentId: environmentStore.activeEnvironmentId
        )
        windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        AppLogger.bootstrapInfo(
            "created new conversation convId=\(conversation.id.uuidString) windowId=\(activeWindow.id.uuidString) path=\(workingDirectory ?? "-")"
        )
    }

    func duplicateActiveConversation() {
        guard let conversation = activeConversation(),
              let duplicate = conversationStore.duplicateConversation(conversation) else {
            AppLogger.bootstrapInfo("duplicate conversation ignored")
            return
        }
        if let activeWindow = windowManager.activeWindow {
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: duplicate)
        }
        AppLogger.bootstrapInfo("duplicated conversation source=\(conversation.id.uuidString) duplicate=\(duplicate.id.uuidString)")
    }

    func refreshActiveConversation() {
        guard let conversation = activeConversation(),
              let sessionId = conversation.sessionId else {
            AppLogger.bootstrapInfo("refresh conversation ignored")
            return
        }
        let workingDirectory = conversation.workingDirectory
            ?? connection.connection(for: conversation.environmentId ?? environmentStore.activeEnvironmentId)?.defaultWorkingDirectory
        guard let workingDirectory, !workingDirectory.isEmpty else {
            AppLogger.bootstrapInfo("refresh conversation ignored missing working directory convId=\(conversation.id.uuidString)")
            return
        }
        AppLogger.beginInterval("conversation.refresh", key: conversation.id.uuidString, details: "sessionId=\(sessionId)")
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory, environmentId: conversation.environmentId)
        AppLogger.bootstrapInfo("refresh conversation convId=\(conversation.id.uuidString)")
    }

    func selectWindow(index: Int) {
        guard index >= 0 && index < windowManager.windows.count else {
            AppLogger.bootstrapInfo("select window ignored index=\(index) count=\(windowManager.windows.count)")
            return
        }
        windowManager.navigateToWindow(at: index)
        AppLogger.bootstrapInfo("selected window index=\(index)")
    }

    func closeActiveWindow() {
        guard let activeWindow = windowManager.activeWindow else {
            AppLogger.bootstrapInfo("close window ignored no active window")
            return
        }
        if let overridePath = fileBrowserRootOverrides.removeValue(forKey: activeWindow.id) {
            AppLogger.bootstrapInfo("cleared file override windowId=\(activeWindow.id.uuidString) path=\(overridePath)")
        }
        if let overridePath = gitRepoRootOverrides.removeValue(forKey: activeWindow.id) {
            AppLogger.bootstrapInfo("cleared git override windowId=\(activeWindow.id.uuidString) path=\(overridePath)")
        }
        guard windowManager.canRemoveWindow else {
            AppLogger.bootstrapInfo("close window ignored only one window")
            return
        }
        windowManager.removeWindow(activeWindow.id)
        AppLogger.bootstrapInfo("closed window id=\(activeWindow.id.uuidString)")
    }

    func openEditActiveWindow() {
        NotificationCenter.default.post(name: .editActiveWindow, object: nil)
        AppLogger.bootstrapInfo("open edit active window")
    }

    func createWindow(type: WindowType? = nil) {
        let newWindowId = windowManager.addWindow()
        if let type {
            windowManager.setWindowType(newWindowId, type: type)
        }
        AppLogger.bootstrapInfo("created window id=\(newWindowId.uuidString) type=\((type ?? .chat).rawValue)")
    }

    func setActiveWindowType(_ type: WindowType) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setWindowType(activeWindow.id, type: type)
        AppLogger.bootstrapInfo("set active window type windowId=\(activeWindow.id.uuidString) type=\(type.rawValue)")
    }

    func selectEnvironment(id: UUID) {
        guard environmentStore.environments.contains(where: { $0.id == id }) else {
            AppLogger.bootstrapInfo("select environment failed envId=\(id.uuidString)")
            return
        }
        environmentStore.setActive(id)
        AppLogger.bootstrapInfo("selected environment envId=\(id.uuidString)")
    }

    func connectEnvironment(id: UUID) {
        guard let environment = environmentStore.environments.first(where: { $0.id == id }) else {
            AppLogger.bootstrapInfo("connect environment failed envId=\(id.uuidString)")
            return
        }
        environmentStore.setActive(id)
        connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
        AppLogger.bootstrapInfo("connect environment envId=\(id.uuidString)")
    }

    func disconnectEnvironment(id: UUID) {
        connection.disconnectEnvironment(id, clearCredentials: false)
        AppLogger.bootstrapInfo("disconnect environment envId=\(id.uuidString)")
    }

    func setActiveConversationEnvironment(id: UUID) {
        guard environmentStore.environments.contains(where: { $0.id == id }),
              let conversation = activeConversation() else {
            AppLogger.bootstrapInfo("set conversation environment ignored envId=\(id.uuidString)")
            return
        }
        conversationStore.setEnvironmentId(conversation, environmentId: id)
        environmentStore.setActive(id)
        AppLogger.bootstrapInfo("set conversation environment convId=\(conversation.id.uuidString) envId=\(id.uuidString)")
    }

    func stopActiveRun() {
        guard let conversation = activeConversation() else {
            AppLogger.bootstrapInfo("stop run ignored no active conversation")
            return
        }
        connection.abort(conversationId: conversation.id)
        AppLogger.bootstrapInfo("stop run convId=\(conversation.id.uuidString)")
    }

    func setActiveConversationModel(_ value: String?) {
        guard let conversation = activeConversation() else { return }
        let model = value.flatMap(ModelSelection.init(rawValue:))
        conversationStore.setDefaultModel(conversation, model: model)
        AppLogger.bootstrapInfo("set conversation model convId=\(conversation.id.uuidString) model=\(model?.rawValue ?? "nil")")
    }

    func setActiveConversationEffort(_ value: String?) {
        guard let conversation = activeConversation() else { return }
        let effort = value.flatMap(EffortLevel.init(rawValue:))
        conversationStore.setDefaultEffort(conversation, effort: effort)
        AppLogger.bootstrapInfo("set conversation effort convId=\(conversation.id.uuidString) effort=\(effort?.rawValue ?? "nil")")
    }

    func openFilesTab(path: String?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setFileBrowserRootPath(activeWindow.id, path: path?.nilIfEmpty)
        windowManager.setWindowType(activeWindow.id, type: .files)
        AppLogger.bootstrapInfo("open files tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
    }

    func openGitTab(path: String?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setGitRepoRootPath(activeWindow.id, path: path?.nilIfEmpty)
        windowManager.setWindowType(activeWindow.id, type: .gitChanges)
        AppLogger.bootstrapInfo("open git tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
    }

    func openGitDiff(repoPath: String?, filePath: String, staged: Bool) {
        let environmentId = activeConversation()?.environmentId ?? environmentStore.activeEnvironmentId
        let resolvedRepoPath = repoPath ?? activeConversation()?.workingDirectory ?? connection.connection(for: environmentId)?.defaultWorkingDirectory ?? "~"
        gitDiffRequest = GitDiffRequest(
            repoPath: resolvedRepoPath,
            file: GitFileStatus(status: "M", path: filePath, staged: staged, additions: nil, deletions: nil),
            environmentId: environmentId
        )
        AppLogger.bootstrapInfo("open git diff repo=\(resolvedRepoPath) file=\(filePath) staged=\(staged)")
    }

    func captureScreenshot() {
        handleScreenshot(conversationId: activeConversation()?.id)
        AppLogger.bootstrapInfo("capture screenshot")
    }

    func sendDebugMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            AppLogger.bootstrapInfo("debug send ignored empty text")
            return
        }

        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else {
            AppLogger.bootstrapInfo("debug send failed missing active window")
            return
        }

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(environmentId: environmentStore.activeEnvironmentId)
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo("debug send created conversation windowId=\(activeWindow.id.uuidString)")
        }
        guard let conv = conversation else {
            AppLogger.bootstrapInfo("debug send failed missing conversation")
            return
        }

        if conv.environmentId == nil {
            conversationStore.setEnvironmentId(conv, environmentId: environmentStore.activeEnvironmentId)
        }
        let updatedConv = conversationStore.conversation(withId: conv.id) ?? conv
        let targetEnvironmentId = updatedConv.environmentId ?? environmentStore.activeEnvironmentId
        let isRunning = connection.output(for: updatedConv.id).isRunning
        let isAuthenticated = connection.connection(for: targetEnvironmentId)?.isAuthenticated ?? connection.isAuthenticated

        if isRunning || !isAuthenticated {
            AppLogger.connectionInfo("debug send queue convId=\(updatedConv.id.uuidString) chars=\(trimmedText.count) running=\(isRunning) authenticated=\(isAuthenticated)")
            let queuedMessage = ChatMessage(isUser: true, text: trimmedText, isQueued: true)
            conversationStore.queueMessage(queuedMessage, to: updatedConv)
            return
        }

        AppLogger.connectionInfo("debug send send convId=\(updatedConv.id.uuidString) chars=\(trimmedText.count)")
        let userMessage = ChatMessage(isUser: true, text: trimmedText)
        conversationStore.addMessage(userMessage, to: updatedConv)

        let isFork = updatedConv.pendingFork
        let isNewSession = updatedConv.sessionId == nil && !isFork
        let effortValue = updatedConv.defaultEffort?.rawValue
        let modelValue = updatedConv.defaultModel?.rawValue
        connection.sendChat(
            trimmedText,
            workingDirectory: updatedConv.workingDirectory,
            sessionId: updatedConv.sessionId,
            isNewSession: isNewSession,
            conversationId: updatedConv.id,
            conversationName: updatedConv.name,
            conversationSymbol: updatedConv.symbol,
            forkSession: isFork,
            effort: effortValue,
            model: modelValue,
            environmentId: updatedConv.environmentId
        )

        if isNewSession {
            AppLogger.connectionInfo("debug send request name suggestion convId=\(updatedConv.id.uuidString)")
            connection.requestNameSuggestion(text: trimmedText, context: [], conversationId: updatedConv.id)
        }

        if isFork {
            AppLogger.connectionInfo("debug send clear pending fork convId=\(updatedConv.id.uuidString)")
            conversationStore.clearPendingFork(updatedConv)
        }
    }
}
