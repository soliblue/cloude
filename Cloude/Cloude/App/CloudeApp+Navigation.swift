import SwiftUI
import CloudeShared

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

    func openEditActiveWindow() {
        NotificationCenter.default.post(name: .editActiveWindow, object: nil)
        AppLogger.bootstrapInfo("open edit active window")
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
}
