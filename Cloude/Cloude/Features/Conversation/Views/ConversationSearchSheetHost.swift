import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func conversationSearchSheetContent() -> some View {
        ConversationSearchSheet(
            conversationStore: conversationStore,
            onSelect: { conversation in
                onSelectConversationFromSearch(conversation)
                store.isShowingConversationSearch = false
            }
        )
    }
}
