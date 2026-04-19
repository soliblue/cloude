import SwiftUI
import CloudeShared

extension WorkspaceView {
    var currentConversation: Conversation? {
        store.currentConversation(windowManager: windowManager, conversationStore: conversationStore)
    }

    var activeEnvConnection: EnvironmentConnection? {
        store.activeEnvConnection(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
    }

    var hasEnvironmentMismatch: Bool {
        store.hasEnvironmentMismatch(environmentStore: environmentStore, windowManager: windowManager, conversationStore: conversationStore)
    }

    var activeWindowIdBinding: Binding<UUID?> {
        Binding(
            get: { windowManager.activeWindowId },
            set: { windowManager.activeWindowId = $0 }
        )
    }

    var editingWindowBinding: Binding<Window?> {
        Binding(get: { store.editingWindow }, set: { store.editingWindow = $0 })
    }

    var showConversationSearchBinding: Binding<Bool> {
        Binding(get: { store.showConversationSearch }, set: { store.showConversationSearch = $0 })
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

    var isKeyboardVisible: Bool {
        get { store.isKeyboardVisible }
        nonmutating set { store.isKeyboardVisible = newValue }
    }

    var currentEffort: EffortLevel? {
        get { store.currentEffort }
        nonmutating set { store.currentEffort = newValue }
    }

    var currentModel: ModelSelection? {
        get { store.currentModel }
        nonmutating set { store.currentModel = newValue }
    }
}
