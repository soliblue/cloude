//
//  WindowConversationPicker.swift
//  Cloude

import SwiftUI

struct WindowConversationPicker: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    let currentWindowId: UUID
    let onSelect: (Project, Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: currentWindowId)
    }

    private var recentConversations: [(Project, Conversation)] {
        projectStore.projects
            .flatMap { project in project.conversations.map { (project, $0) } }
            .filter { !openInOtherWindows.contains($0.1.id) }
            .sorted { $0.1.lastMessageAt > $1.1.lastMessageAt }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recentConversations.isEmpty {
                    Section("Recent") {
                        ForEach(recentConversations, id: \.1.id) { project, conversation in
                            conversationRow(conversation, showFolder: true)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(project, conversation) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteConversation(conversation, from: project)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                ForEach(projectStore.projects) { project in
                    Section(folderName(for: project)) {
                        ForEach(project.conversations.filter { !openInOtherWindows.contains($0.id) }) { conversation in
                            conversationRow(conversation)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(project, conversation) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteConversation(conversation, from: project)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }

                        Button(action: { createNewConversation(in: project) }) {
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
            .background(.ultraThinMaterial)
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(connection: connection) { path in
                    createNewProject(at: path)
                }
            }
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
                if showFolder, let path = conversation.workingDirectory, !path.isEmpty {
                    Text((path as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(conversation.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func folderName(for project: Project) -> String {
        if !project.rootDirectory.isEmpty {
            return (project.rootDirectory as NSString).lastPathComponent
        }
        return project.name
    }

    private func createNewConversation(in project: Project) {
        let workingDir = project.rootDirectory.isEmpty ? nil : project.rootDirectory
        let newConv = projectStore.newConversation(in: project, workingDirectory: workingDir)
        onSelect(project, newConv)
    }

    private func createNewProject(at path: String) {
        let folderName = (path as NSString).lastPathComponent
        let project = projectStore.createProject(name: folderName, rootDirectory: path)
        let conversation = projectStore.newConversation(in: project, workingDirectory: path)
        onSelect(project, conversation)
    }

    private func deleteConversation(_ conversation: Conversation, from project: Project) {
        let isCurrentWindowConversation = windowManager.windows
            .first(where: { $0.id == currentWindowId })?.conversationId == conversation.id
        projectStore.deleteConversation(conversation, from: project)
        if isCurrentWindowConversation {
            windowManager.removeWindow(currentWindowId)
            dismiss()
        }
    }
}
