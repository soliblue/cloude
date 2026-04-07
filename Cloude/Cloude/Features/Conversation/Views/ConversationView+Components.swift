import SwiftUI
import Combine
import CloudeShared

struct ChatMessageList: View {
    @AppStorage("fontSizeStep") var fontSizeStep = 0
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let conversationId: UUID?
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?
    var onDeleteQueued: ((UUID) -> Void)?
    var conversation: Conversation?
    var conversationStore: ConversationStore?
    var connection: ConnectionManager?
    var window: Window?
    var windowManager: WindowManager?
    var onSelectConversation: ((Conversation) -> Void)?
    var onSeeAllConversations: (() -> Void)?
    var environmentStore: EnvironmentStore?
    var conversationOutput: ConversationOutput?

    @State var isInitialLoad = true
    @State var refreshingMessageId: UUID?
    @State var selectedToolDetail: ToolDetailItem?

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

    private var hideMessageList: Bool {
        showEmptyState && hasRequiredDependencies
    }

    var body: some View {
        let _ = NSLog("[STABILITY] ChatMessageList.body | msgs=\(messages.count) queued=\(queuedMessages.count) loading=\(showLoadingIndicator) empty=\(showEmptyState) deps=\(hasRequiredDependencies) initialLoad=\(isInitialLoad) outputEmpty=\(isOutputEmpty) streaming=\(isStreaming) convId=\(conversationId?.uuidString.prefix(6) ?? "nil")")
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
                ScrollView(showsIndicators: false) {
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
                    .containerRelativeFrame(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            scrollableContent
                .opacity(hideMessageList ? 0 : 1)
                .allowsHitTesting(!hideMessageList)
        }
        .background(Color.themeBackground)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = messages.isEmpty
        }
    }
}
