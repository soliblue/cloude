import SwiftUI
import CloudeShared

struct WindowEditForm: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false
    @State private var showFolderPicker = false

    private var conversation: Conversation? {
        window.conversationId.flatMap { conversationStore.conversation(withId: $0) }
    }

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: window.id)
    }

    private var allConversations: [Conversation] {
        conversationStore.listableConversations
            .filter { $0.id != conversation?.id && !openInOtherWindows.contains($0.id) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    private var canChangeFolder: Bool {
        guard let conv = conversation else { return false }
        return conv.messages.isEmpty && conv.sessionId == nil
    }

    private var currentFolderPath: String {
        conversation?.workingDirectory ?? ""
    }

    private var folderDisplayName: String {
        let path = currentFolderPath
        if path.isEmpty { return "No folder selected" }
        return path.lastPathComponent
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button(action: { showSymbolPicker = true }) {
                    Image.safeSymbol(symbol.nilIfEmpty, fallback: "circle.dashed")
                        .font(.system(size: 24))
                        .frame(width: 48, height: 48)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                TextField("Name", text: $name)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: name) { _, newValue in
                        if let conv = conversation, !newValue.isEmpty {
                            conversationStore.renameConversation(conv, to: newValue)
                        }
                    }
            }

            if canChangeFolder {
                Button(action: { showFolderPicker = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folderDisplayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            if !currentFolderPath.isEmpty {
                                Text(currentFolderPath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                        }
                        Spacer()
                        Text("Change")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if !allConversations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(allConversations) { conv in
                        Button(action: { onSelectConversation(conv) }) {
                            HStack(spacing: 10) {
                                Image.safeSymbol(conv.symbol)
                                    .font(.system(size: 17))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conv.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        if let dir = conv.workingDirectory, !dir.isEmpty {
                                            Text(dir.lastPathComponent)
                                                .foregroundColor(.accentColor)
                                        }
                                        Text("\(conv.messages.count) msgs")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption2)
                                }
                                Spacer()
                                Text(relativeTime(conv.lastMessageAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if conv.id != allConversations.last?.id {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheet(selectedSymbol: $symbol)
        }
        .onChange(of: symbol) { _, newValue in
            if let conv = conversation {
                conversationStore.setConversationSymbol(conv, symbol: newValue.nilIfEmpty)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(connection: connection) { path in
                if let conv = conversation {
                    conversationStore.setWorkingDirectory(conv, path: path)
                }
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

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
