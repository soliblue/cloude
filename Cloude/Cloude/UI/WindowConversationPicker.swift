import SwiftUI
import CloudeShared

struct WindowConversationPicker: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let currentWindowId: UUID
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false
    @State private var remoteSessions: [RemoteSession] = []
    @State private var isLoadingRemote = false
    @State private var sortBy: SortOption = .recency

    enum SortOption: String, CaseIterable {
        case recency = "Recent"
        case messages = "Messages"
    }

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: currentWindowId)
    }

    private var recentConversations: [Conversation] {
        conversationStore.listableConversations
            .filter { !openInOtherWindows.contains($0.id) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .prefix(5)
            .map { $0 }
    }

    private var recentConversationIds: Set<UUID> {
        Set(recentConversations.map(\.id))
    }

    private var existingSessionIds: Set<String> {
        Set(conversationStore.listableConversations.compactMap { $0.sessionId })
    }

    private var totalConversationCount: Int {
        conversationStore.listableConversations.count
    }

    private func sortedConversations(_ conversations: [Conversation]) -> [Conversation] {
        switch sortBy {
        case .recency:
            return conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
        case .messages:
            return conversations.sorted { $0.messages.count > $1.messages.count }
        }
    }

    private var laptopOnlySessions: [RemoteSession] {
        remoteSessions
            .filter { !existingSessionIds.contains($0.sessionId) }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recentConversations.isEmpty {
                    Section("Recent") {
                        ForEach(recentConversations, id: \.id) { conversation in
                            conversationRow(conversation, showFolder: true)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(conversation) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteConversation(conversation)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if !laptopOnlySessions.isEmpty {
                    Section("From Laptop") {
                        ForEach(laptopOnlySessions) { session in
                            remoteSessionRow(session)
                                .contentShape(Rectangle())
                                .onTapGesture { importSession(session) }
                        }
                    }
                } else if isLoadingRemote {
                    Section("From Laptop") {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                ForEach(conversationStore.conversationsByDirectory, id: \.directory) { group in
                    Section(folderName(for: group.directory)) {
                        ForEach(sortedConversations(group.conversations.filter { !openInOtherWindows.contains($0.id) && !recentConversationIds.contains($0.id) })) { conversation in
                            conversationRow(conversation)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(conversation) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteConversation(conversation)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }

                        Button(action: { createNewConversation(workingDirectory: group.directory) }) {
                            Label("New Chat", systemImage: "plus")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                Section {
                    Button(action: { showFolderPicker = true }) {
                        Label("New Project", systemImage: "folder.badge.plus")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("\(totalConversationCount) Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option == .recency ? "clock" : "bubble.left.and.bubble.right")
                                    .tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: sortBy == .recency ? "clock" : "bubble.left.and.bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(connection: connection) { path in
                    createNewFolder(at: path)
                }
            }
            .onAppear { fetchRemoteSessions() }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation, showFolder: Bool = false) -> some View {
        HStack {
            if conversation.symbol.isValidSFSymbol {
                Image.safeSymbol(conversation.symbol)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.name)
                    .font(.body)
                HStack(spacing: 4) {
                    if showFolder, let path = conversation.workingDirectory, !path.isEmpty {
                        Text((path as NSString).lastPathComponent)
                        Text("·")
                    }
                    Text("\(conversation.messages.count) messages")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func folderName(for directory: String) -> String {
        if !directory.isEmpty {
            return (directory as NSString).lastPathComponent
        }
        return "Default"
    }

    private func createNewConversation(workingDirectory: String) {
        let wd = workingDirectory.isEmpty ? nil : workingDirectory
        let newConv = conversationStore.newConversation(workingDirectory: wd)
        onSelect(newConv)
    }

    private func createNewFolder(at path: String) {
        let conversation = conversationStore.newConversation(workingDirectory: path)
        onSelect(conversation)
    }

    private func deleteConversation(_ conversation: Conversation) {
        let isCurrentWindowConversation = windowManager.windows
            .first(where: { $0.id == currentWindowId })?.conversationId == conversation.id
        withAnimation {
            conversationStore.deleteConversation(conversation)
        }
        if isCurrentWindowConversation {
            windowManager.removeWindow(currentWindowId)
            dismiss()
        }
    }

    @ViewBuilder
    private func remoteSessionRow(_ session: RemoteSession) -> some View {
        HStack {
            Image(systemName: "laptopcomputer")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(timeAgo(session.lastModified))
                    .font(.body)
                Text("\(session.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.caption)
                .foregroundColor(.accentColor)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fetchRemoteSessions() {
        let firstDir = conversationStore.uniqueWorkingDirectories.first
        guard let dir = firstDir else { return }

        isLoadingRemote = true
        connection.onRemoteSessionList = { sessions in
            self.remoteSessions = sessions
            self.isLoadingRemote = false
        }
        connection.listRemoteSessions(workingDirectory: dir)
    }

    private func importSession(_ session: RemoteSession) {
        var newConv = Conversation(name: "Imported Chat", symbol: "laptopcomputer")
        newConv.sessionId = session.sessionId
        newConv.workingDirectory = session.workingDirectory

        conversationStore.addConversation(newConv)
        connection.syncHistory(sessionId: session.sessionId, workingDirectory: session.workingDirectory)
        onSelect(newConv)
    }
}
