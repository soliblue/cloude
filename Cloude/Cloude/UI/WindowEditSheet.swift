//
//  WindowEditSheet.swift
//  Cloude

import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let onSelectConversation: (Conversation) -> Void
    let onShowAllConversations: () -> Void
    let onNewConversation: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false
    @State private var showFolderPicker = false

    private var project: Project? {
        window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
    }

    private var conversation: Conversation? {
        project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
    }

    private var recentConversations: [Conversation] {
        guard let proj = project else { return [] }
        return proj.conversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .filter { $0.id != conversation?.id }
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
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: { showSymbolPicker = true }) {
                        Image.safeSymbol(symbol.isEmpty ? nil : symbol, fallback: "circle.dashed")
                            .font(.system(size: 30))
                            .frame(width: 56, height: 56)
                            .background(Color.oceanSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $name)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        .background(Color.oceanSurface)
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
                                Button(action: {
                                    onSelectConversation(conv)
                                }) {
                                    HStack(spacing: 10) {
                                        Image.safeSymbol(conv.symbol)
                                            .font(.system(size: 17))
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                        Text(conv.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
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
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onNewConversation) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 18))
                            Text("New")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if windowManager.canRemoveWindow {
                        Button(action: {
                            windowManager.removeWindow(window.id)
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 18))
                                Text("Remove")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.oceanSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Edit Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let proj = project, let conv = conversation {
                            if !name.isEmpty {
                                projectStore.renameConversation(conv, in: proj, to: name)
                            }
                            projectStore.setConversationSymbol(conv, in: proj, symbol: symbol.isEmpty ? nil : symbol)
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerSheet(selectedSymbol: $symbol)
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(connection: connection) { path in
                    if let proj = project, let conv = conversation {
                        projectStore.setWorkingDirectory(conv, in: proj, path: path)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .scrollContentBackground(.hidden)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.height(480)])
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
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
