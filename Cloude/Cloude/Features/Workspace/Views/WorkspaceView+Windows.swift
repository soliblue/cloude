import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func windowPage(for window: Window, isActive: Bool) -> some View {
        if isActive {
            pagedWindowContent(for: window)
                .opacity(1)
                .zIndex(1)
                .allowsHitTesting(true)
                .animation(.easeIn(duration: 0.2).delay(0.01), value: currentPageIndex)
        } else {
            InactiveWindowPage(
                snapshot: .init(
                    id: window.id,
                    tab: window.tab,
                    conversationId: window.conversationId,
                    fileBrowserRootPath: window.fileBrowserRootPath,
                    gitRepoRootPath: window.gitRepoRootPath
                ),
                content: { AnyView(pagedWindowContent(for: window)) }
            )
            .opacity(0)
            .zIndex(0)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.2).delay(0.2), value: currentPageIndex)
        }
    }

    @ViewBuilder
    func pagedWindowContent(for window: Window) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            WindowTabBar(
                activeTab: window.tab,
                envConnected: (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false,
                connection: connection,
                repoPath: window.gitRepoRootPath ?? conversation?.workingDirectory,
                environmentId: conversation?.environmentId,
                folderName: conversation?.workingDirectory.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).lastPathComponent },
                totalCost: conversation?.totalCost ?? 0,
                onSelectTab: { tab in withAnimation(.easeInOut(duration: DS.Duration.s)) { windowManager.setWindowTab(window.id, tab: tab) } }
            )
            .equatable()

            ZStack {
                ConversationView(
                    connection: connection,
                    store: conversationStore,
                    environmentStore: environmentStore,
                    conversation: conversation,
                    window: window,
                    windowManager: windowManager,
                    onSelectConversation: nil,
                    onInteraction: { dismissKeyboard() },
                    onSelectRecentConversation: { conv in
                        windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    },
                    onSeeAllConversations: {
                        store.openConversationSearch()
                    }
                )
                .id(window.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .chat ? 1 : 0)
                .allowsHitTesting(window.tab == .chat)

                FileTreeView(
                    connection: connection,
                    rootPath: window.fileBrowserRootPath ?? conversation?.workingDirectory,
                    environmentId: conversation?.environmentId,
                    isVisible: window.tab == .files,
                    state: windowManager.fileTreeState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .files ? 1 : 0)
                .allowsHitTesting(window.tab == .files)

                GitChangesView(
                    connection: connection,
                    rootPath: window.gitRepoRootPath ?? conversation?.workingDirectory,
                    environmentId: conversation?.environmentId,
                    state: windowManager.gitChangesState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .gitChanges ? 1 : 0)
                .allowsHitTesting(window.tab == .gitChanges)

            }
        }
    }
}

private struct InactiveWindowPageSnapshot: Equatable {
    let id: UUID
    let tab: WindowTab
    let conversationId: UUID?
    let fileBrowserRootPath: String?
    let gitRepoRootPath: String?
}

private struct InactiveWindowPage: View, Equatable {
    let snapshot: InactiveWindowPageSnapshot
    let content: () -> AnyView

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snapshot == rhs.snapshot
    }

    var body: some View {
        content()
    }
}
