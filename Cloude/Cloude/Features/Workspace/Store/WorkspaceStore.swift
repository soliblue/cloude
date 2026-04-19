import Foundation
import SwiftUI
import Combine
import Photos
import UIKit
import CloudeShared

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var editingWindow: Window?
    @Published var isKeyboardVisible = false
    @Published var inputText = ""
    @Published var attachedImages: [AttachedImage] = []
    @Published var attachedFiles: [AttachedFile] = []
    @Published var drafts: [UUID: Draft] = [:]
    @Published var gitBranches: [String: String] = [:]
    @Published var gitStats: [String: (additions: Int, deletions: Int)] = [:]
    @Published var pendingGitChecks: [(path: String, environmentId: UUID?)] = []
    @Published var fileSearchResults: [String] = []
    @Published var currentEffort: EffortLevel?
    @Published var currentModel: ModelSelection?
    @Published var showConversationSearch = false
    @Published var refreshingSessionIds: Set<String> = []

    func currentConversation(windowManager: WindowManager, conversationStore: ConversationStore) -> Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    func activeEnvConnection(
        connection: ConnectionManager,
        windowManager: WindowManager,
        conversationStore: ConversationStore,
        environmentStore: EnvironmentStore
    ) -> EnvironmentConnection? {
        let envId = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
        return connection.connection(for: envId)
    }

    func hasEnvironmentMismatch(
        connection: ConnectionManager,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> Bool {
        if let envId = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId {
            return connection.connection(for: envId)?.phase != .authenticated
        }
        return false
    }

    func activeConversationIsRunning(connection: ConnectionManager, windowManager: WindowManager) -> Bool {
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId {
            return connection.output(for: convId).phase != .idle
        }
        return false
    }

    func activeWindowWorkingDirectory(windowManager: WindowManager, conversationStore: ConversationStore) -> String? {
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId,
           let conv = conversationStore.conversation(withId: convId) {
            return conv.workingDirectory
        }
        return nil
    }

    func activeWindowEnvironmentId(
        windowManager: WindowManager,
        conversationStore: ConversationStore,
        environmentStore: EnvironmentStore
    ) -> UUID? {
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId,
           let conv = conversationStore.conversation(withId: convId) {
            return conv.environmentId ?? environmentStore.activeEnvironmentId
        }
        return environmentStore.activeEnvironmentId
    }
}
