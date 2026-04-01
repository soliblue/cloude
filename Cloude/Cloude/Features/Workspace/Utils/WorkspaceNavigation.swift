import SwiftUI
import CloudeShared

extension Notification.Name {
    static let openConversationSearch = Notification.Name("openConversationSearch")
    static let requestUsageStats = Notification.Name("requestUsageStats")
    static let dismissWorkspaceTransientUI = Notification.Name("dismissWorkspaceTransientUI")
}

extension App {
    func dismissTransientUI() {
        settingsStore.isPresented = false
        memoriesStore.isPresented = false
        plansStore.isPresented = false
        whiteboardStore.isPresented = false
        filePathToPreview = nil
        gitDiffRequest = nil
        NotificationCenter.default.post(name: .dismissWorkspaceTransientUI, object: nil)
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
        windowManager.setWindowTab(activeWindow.id, tab: .files)
        AppLogger.bootstrapInfo("open files tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
    }

    func openGitTab(path: String?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setGitRepoRootPath(activeWindow.id, path: path?.nilIfEmpty)
        windowManager.setWindowTab(activeWindow.id, tab: .gitChanges)
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
