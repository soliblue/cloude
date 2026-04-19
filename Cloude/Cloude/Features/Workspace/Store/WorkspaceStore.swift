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

    func activeRuntimeContext(
        environmentStore: EnvironmentStore,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> WindowRuntimeContext {
        if let activeWindow = windowManager.activeWindow {
            return activeWindow.runtimeContext(conversationStore: conversationStore, environmentStore: environmentStore)
        }
        let environmentId = environmentStore.activeEnvironmentId
        let environment = environmentStore.environments.first { $0.id == environmentId }
        let connection = environmentStore.connection(for: environmentId)
        return WindowRuntimeContext(
            conversation: nil,
            environmentId: environmentId,
            environment: environment,
            connection: connection,
            workingDirectory: connection?.defaultWorkingDirectory?.nilIfEmpty
        )
    }

    func activeEnvConnection(
        environmentStore: EnvironmentStore,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> EnvironmentConnection? {
        activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        ).connection
    }

    func hasEnvironmentMismatch(
        environmentStore: EnvironmentStore,
        windowManager: WindowManager,
        conversationStore: ConversationStore
    ) -> Bool {
        let runtime = activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
        if runtime.conversation?.environmentId != nil {
            return runtime.connection?.isReady != true
        }
        return false
    }
}
