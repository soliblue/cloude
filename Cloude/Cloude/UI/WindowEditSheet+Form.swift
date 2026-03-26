import SwiftUI
import CloudeShared

struct WindowEditForm: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
    let onSelectConversation: (Conversation) -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false
    @State var visibleCount = 20

    private var conversation: Conversation? {
        window.conversation(in: conversationStore)
    }

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: window.id)
    }

    var allConversations: [Conversation] {
        conversationStore.listableConversations
            .filter { $0.id != conversation?.id && !openInOtherWindows.contains($0.id) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    private var canChangeFolder: Bool {
        guard let conv = conversation else { return false }
        return conv.messages.isEmpty && conv.sessionId == nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button(action: { showSymbolPicker = true }) {
                    Image.safeSymbol(symbol.nilIfEmpty, fallback: "circle.dashed")
                        .font(.system(size: DS.Icon.l))
                        .frame(width: 48, height: 48)
                        .background(Color.themeSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)

                TextField("Name", text: $name)
                    .font(.system(size: DS.Text.m))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.themeSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .onChange(of: name) { _, newValue in
                        if let conv = conversation, !newValue.isEmpty {
                            conversationStore.renameConversation(conv, to: newValue)
                        }
                    }
            }

            if let conv = conversation {
                EnvironmentFolderPicker(
                    environmentStore: environmentStore,
                    connection: connection,
                    conversationStore: conversationStore,
                    conversation: conv,
                    editable: canChangeFolder
                )
            }

            conversationListSection()
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheet(selectedSymbol: $symbol)
        }
        .onChange(of: symbol) { _, newValue in
            if let conv = conversation {
                conversationStore.setConversationSymbol(conv, symbol: newValue.nilIfEmpty)
            }
        }
        .onAppear {
            name = conversation?.name ?? ""
            symbol = conversation?.symbol ?? ""
        }
        .onChange(of: conversation?.id) { _, _ in
            name = conversation?.name ?? ""
            symbol = conversation?.symbol ?? ""
        }
    }
}
