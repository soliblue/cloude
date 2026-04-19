import SwiftUI
import CloudeShared

extension Notification.Name {
    static let openConversationSearch = Notification.Name("openConversationSearch")
    static let dismissWorkspaceTransientUI = Notification.Name("dismissWorkspaceTransientUI")
    static let editActiveWindow = Notification.Name("editActiveWindow")
}

extension App {
    func dismissTransientUI() {
        settingsStore.isPresented = false
        filePathToPreview = nil
        gitDiffRequest = nil
        NotificationCenter.default.post(name: .dismissWorkspaceTransientUI, object: nil)
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

        if let activeWindow = windowManager.ensureActiveWindow() {
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo("conversation search selected convId=\(conversation.id.uuidString) query=\(trimmedQuery)")
        }
    }

    func openEditActiveWindow() {
        NotificationCenter.default.post(name: .editActiveWindow, object: nil)
        AppLogger.bootstrapInfo("open edit active window")
    }

    func openFilesTab(path: String?) {
        guard let activeWindow = windowManager.ensureActiveWindow() else { return }
        windowManager.setFileBrowserRootPath(activeWindow.id, path: path?.nilIfEmpty)
        windowManager.setWindowTab(activeWindow.id, tab: .files)
        AppLogger.bootstrapInfo("open files tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
    }

    func openGitTab(path: String?) {
        guard let activeWindow = windowManager.ensureActiveWindow() else { return }
        windowManager.setGitRepoRootPath(activeWindow.id, path: path?.nilIfEmpty)
        windowManager.setWindowTab(activeWindow.id, tab: .gitChanges)
        AppLogger.bootstrapInfo("open git tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
    }

    func openGitDiff(repoPath: String?, filePath: String, staged: Bool) {
        let runtime = windowManager.activeWindow?.runtimeContext(
            conversationStore: conversationStore,
            environmentStore: environmentStore
        )
        let resolvedRepoPath = repoPath ?? runtime?.workingDirectory ?? "~"
        gitDiffRequest = GitDiffRequest(
            repoPath: resolvedRepoPath,
            file: GitFileStatus(status: "M", path: filePath, staged: staged, additions: nil, deletions: nil),
            environmentId: runtime?.environmentId
        )
        AppLogger.bootstrapInfo("open git diff repo=\(resolvedRepoPath) file=\(filePath) staged=\(staged)")
    }

    func captureScreenshot() {
        handleScreenshot(conversationId: activeConversation()?.id)
        AppLogger.bootstrapInfo("capture screenshot")
    }
}
