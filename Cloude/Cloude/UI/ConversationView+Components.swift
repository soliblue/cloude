import SwiftUI
import Combine
import CloudeShared

struct ChatMessageList: View {
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let agentState: AgentState
    let conversationId: UUID?
    var isCompact: Bool = false
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?
    var onDeleteQueued: ((UUID) -> Void)?
    var conversation: Conversation?
    var conversationStore: ConversationStore?
    var connection: ConnectionManager?
    var window: ChatWindow?
    var windowManager: WindowManager?
    var onSelectConversation: ((Conversation) -> Void)?
    var onSeeAllConversations: (() -> Void)?
    var onNewConversation: (() -> Void)?
    var environmentStore: EnvironmentStore?
    var conversationOutput: ConversationOutput?

    @State var isInitialLoad = true
    @State var scrollViewportHeight: CGFloat = 0
    @State var refreshingMessageId: UUID?
    @State var scrollPos = ScrollPosition()

    private var isOutputEmpty: Bool {
        conversationOutput?.text.isEmpty ?? true
    }

    private var isStreaming: Bool {
        conversationOutput?.isRunning ?? false
    }

    private var showLoadingIndicator: Bool {
        isInitialLoad && messages.isEmpty && conversationId != nil && isOutputEmpty && !isStreaming
    }

    private var showEmptyState: Bool {
        !isInitialLoad && messages.isEmpty && queuedMessages.isEmpty && isOutputEmpty && conversationId != nil && !isStreaming
    }

    private var hasRequiredDependencies: Bool {
        window != nil && conversationStore != nil && windowManager != nil && connection != nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showLoadingIndicator {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(DS.Scale.l)
                        .tint(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showEmptyState {
                EmptyConversationView(
                    connection: connection,
                    conversationStore: conversationStore,
                    environmentStore: environmentStore,
                    conversation: conversation,
                    windowManager: windowManager,
                    window: window,
                    onSelectConversation: onSelectConversation,
                    onSeeAll: onSeeAllConversations
                )
            }

            if !showEmptyState || !hasRequiredDependencies {
                scrollableContent
            }
        }
        .background(Color.themeBackground)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = messages.isEmpty
        }
    }
}
