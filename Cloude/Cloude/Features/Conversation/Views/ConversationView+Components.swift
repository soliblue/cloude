import SwiftUI
import Combine
import CloudeShared

struct ChatMessageList: View {
    @AppStorage("fontSizeStep") var fontSizeStep = 0
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let conversationId: UUID?
    var onInteraction: (() -> Void)?
    var onDeleteQueued: ((UUID) -> Void)?
    var conversation: Conversation?
    var conversationStore: ConversationStore?
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
        (conversationOutput?.phase ?? .idle) != .idle
    }

    private var showLoadingIndicator: Bool {
        isInitialLoad && messages.isEmpty && conversationId != nil && isOutputEmpty && !isStreaming
    }

    private var showEmptyState: Bool {
        !isInitialLoad && messages.isEmpty && queuedMessages.isEmpty && isOutputEmpty && conversationId != nil && !isStreaming
    }

    private var hasRequiredDependencies: Bool {
        window != nil && conversationStore != nil && windowManager != nil && environmentStore != nil
    }

    private var hideMessageList: Bool {
        showEmptyState && hasRequiredDependencies
    }

    var body: some View {
        if let output = conversationOutput {
            ChatMessageListObservedBody(output: output) {
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            if showLoadingIndicator {
                ProgressView()
                    .scaleEffect(DS.Scale.l)
                    .tint(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showEmptyState {
                ScrollView(showsIndicators: false) {
                    EmptyConversationView(
                        conversationStore: conversationStore,
                        environmentStore: environmentStore,
                        conversation: conversation,
                        windowManager: windowManager,
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

private struct ChatMessageListObservedBody<Content: View>: View {
    @ObservedObject var output: ConversationOutput
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}
