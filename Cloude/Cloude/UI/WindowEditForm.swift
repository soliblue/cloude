//
//  WindowEditForm.swift
//  Cloude

import SwiftUI
import CloudeShared

struct WindowEditForm: View {
    let window: ChatWindow
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void
    let onShowAllConversations: () -> Void
    let onNewConversation: () -> Void
    var showRemoveButton: Bool = true
    var onRemove: (() -> Void)?
    var onRefresh: (() async -> Void)?
    var onDuplicate: ((Conversation) -> Void)?

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false
    @State private var showFolderPicker = false
    @State private var isRefreshing = false

    private var project: Project? {
        window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
    }

    private var conversation: Conversation? {
        project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
    }

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: window.id)
    }

    private var recentConversations: [Conversation] {
        guard let proj = project else { return [] }
        return proj.conversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .filter { $0.id != conversation?.id && !openInOtherWindows.contains($0.id) }
            .prefix(5)
            .map { $0 }
    }

    private var canChangeFolder: Bool {
        guard let conv = conversation else { return false }
        return conv.messages.isEmpty && conv.sessionId == nil
    }

    private var currentFolderPath: String {
        conversation?.workingDirectory ?? project?.rootDirectory ?? ""
    }

    private var folderDisplayName: String {
        let path = currentFolderPath
        if path.isEmpty { return "No folder selected" }
        return (path as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button(action: { showSymbolPicker = true }) {
                    Image.safeSymbol(symbol.isEmpty ? nil : symbol, fallback: "circle.dashed")
                        .font(.system(size: 30))
                        .frame(width: 56, height: 56)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                TextField("Name", text: $name)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: name) { _, newValue in
                        if let proj = project, let conv = conversation, !newValue.isEmpty {
                            projectStore.renameConversation(conv, in: proj, to: newValue)
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

            if !recentConversations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: onShowAllConversations) {
                            Text("See All")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(recentConversations) { conv in
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
                                        if let dir = conv.workingDirectory {
                                            Text((dir as NSString).lastPathComponent)
                                                .font(.caption2)
                                                .foregroundColor(.accentColor)
                                                .lineLimit(1)
                                        }
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

                            if conv.id != recentConversations.last?.id {
                                Divider()
                                    .padding(.leading, 46)
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack(spacing: 12) {
                Button(action: onNewConversation) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if let conv = conversation, conv.sessionId != nil, let proj = project {
                    Button {
                        if let newConv = projectStore.duplicateConversation(conv, in: proj) {
                            onDuplicate?(newConv)
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                if onRefresh != nil {
                    Button {
                        guard !isRefreshing else { return }
                        isRefreshing = true
                        Task {
                            await onRefresh?()
                            isRefreshing = false
                        }
                    } label: {
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }

                Spacer()

                if showRemoveButton && windowManager.canRemoveWindow {
                    Button(action: { onRemove?() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheet(selectedSymbol: $symbol)
        }
        .onChange(of: symbol) { _, newValue in
            if let proj = project, let conv = conversation {
                projectStore.setConversationSymbol(conv, in: proj, symbol: newValue.isEmpty ? nil : newValue)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(connection: connection) { path in
                if let proj = project, let conv = conversation {
                    projectStore.setWorkingDirectory(conv, in: proj, path: path)
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
