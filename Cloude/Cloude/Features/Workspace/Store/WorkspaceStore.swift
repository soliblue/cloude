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
    @Published var currentEffort: EffortLevel?
    @Published var currentModel: ModelSelection?
    @Published var showConversationSearch = false

    func currentConversation(windowManager: WindowManager, conversationStore: ConversationStore) -> Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    func activeEnvConnection(
        environmentStore: EnvironmentStore,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> EnvironmentConnection? {
        let envId = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
        return environmentStore.connection(for: envId)
    }

    func hasEnvironmentMismatch(
        environmentStore: EnvironmentStore,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> Bool {
        if let envId = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId {
            return environmentStore.connection(for: envId)?.isReady != true
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
