import SwiftUI

extension WorkspaceView {
    var activeWindowIdBinding: Binding<UUID?> {
        Binding(
            get: { windowManager.activeWindowId },
            set: { windowManager.activeWindowId = $0 }
        )
    }

    var windowBeingEditedBinding: Binding<Window?> {
        Binding(get: { store.windowBeingEdited }, set: { store.windowBeingEdited = $0 })
    }

    var isShowingConversationSearchBinding: Binding<Bool> {
        Binding(get: { store.isShowingConversationSearch }, set: { store.isShowingConversationSearch = $0 })
    }

    var isKeyboardVisible: Bool {
        get { store.isKeyboardVisible }
        nonmutating set { store.isKeyboardVisible = newValue }
    }
}
