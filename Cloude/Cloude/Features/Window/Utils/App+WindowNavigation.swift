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
        let conversation = conversationStore.conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }.first { conv in
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
            windowManager.selectConversation(
                conversation,
                in: activeWindow.id,
                conversationStore: conversationStore
            )
            AppLogger.bootstrapInfo("conversation search selected convId=\(conversation.id.uuidString) query=\(trimmedQuery)")
        }
    }

    func openEditActiveWindow() {
        NotificationCenter.default.post(name: .editActiveWindow, object: nil)
        AppLogger.bootstrapInfo("open edit active window")
    }

    func openFilesTab(path: String?) {
        if let activeWindow = windowManager.ensureActiveWindow() {
            if let path = path?.nilIfEmpty {
                let environmentId = activeWindow.runtimeEnvironmentId(
                    conversationStore: conversationStore,
                    environmentStore: environmentStore
                )
                if activeWindow.conversation(in: conversationStore)?.workingDirectory?.nilIfEmpty != path {
                    if let conversation = conversationStore.conversations
                        .sorted(by: { $0.lastMessageAt > $1.lastMessageAt })
                        .first(where: { $0.workingDirectory?.nilIfEmpty == path && $0.environmentId == environmentId }) {
                        windowManager.selectConversation(
                            conversation,
                            in: activeWindow.id,
                            conversationStore: conversationStore
                        )
                    } else {
                        let conversation = conversationStore.newConversation(workingDirectory: path, environmentId: environmentId)
                        windowManager.selectConversation(
                            conversation,
                            in: activeWindow.id,
                            conversationStore: conversationStore
                        )
                    }
                }
            }
            windowManager.setWindowTab(activeWindow.id, tab: .files)
            AppLogger.bootstrapInfo("open files tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
        }
    }

    func openGitTab(path: String?) {
        if let activeWindow = windowManager.ensureActiveWindow() {
            if let path = path?.nilIfEmpty {
                let environmentId = activeWindow.runtimeEnvironmentId(
                    conversationStore: conversationStore,
                    environmentStore: environmentStore
                )
                if activeWindow.conversation(in: conversationStore)?.workingDirectory?.nilIfEmpty != path {
                    if let conversation = conversationStore.conversations
                        .sorted(by: { $0.lastMessageAt > $1.lastMessageAt })
                        .first(where: { $0.workingDirectory?.nilIfEmpty == path && $0.environmentId == environmentId }) {
                        windowManager.selectConversation(
                            conversation,
                            in: activeWindow.id,
                            conversationStore: conversationStore
                        )
                    } else {
                        let conversation = conversationStore.newConversation(workingDirectory: path, environmentId: environmentId)
                        windowManager.selectConversation(
                            conversation,
                            in: activeWindow.id,
                            conversationStore: conversationStore
                        )
                    }
                }
            }
            windowManager.setWindowTab(activeWindow.id, tab: .gitChanges)
            AppLogger.bootstrapInfo("open git tab windowId=\(activeWindow.id.uuidString) path=\(path ?? "-")")
        }
    }

    func openGitDiff(repoPath: String?, filePath: String, staged: Bool) {
        if let activeWindow = windowManager.ensureActiveWindow(),
           let repoPath = repoPath?.nilIfEmpty {
            let environmentId = activeWindow.runtimeEnvironmentId(
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
            if activeWindow.conversation(in: conversationStore)?.workingDirectory?.nilIfEmpty != repoPath {
                if let conversation = conversationStore.conversations
                    .sorted(by: { $0.lastMessageAt > $1.lastMessageAt })
                    .first(where: { $0.workingDirectory?.nilIfEmpty == repoPath && $0.environmentId == environmentId }) {
                    windowManager.selectConversation(
                        conversation,
                        in: activeWindow.id,
                        conversationStore: conversationStore
                    )
                } else {
                    let conversation = conversationStore.newConversation(workingDirectory: repoPath, environmentId: environmentId)
                    windowManager.selectConversation(
                        conversation,
                        in: activeWindow.id,
                        conversationStore: conversationStore
                    )
                }
            }
        }
        let runtime = windowManager.activeWindow?.runtimeContext(
            conversationStore: conversationStore,
            environmentStore: environmentStore
        )
        let resolvedRepoPath = repoPath?.nilIfEmpty ?? runtime?.workingDirectory ?? "~"
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
