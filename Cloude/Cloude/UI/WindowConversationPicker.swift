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
                            Button(action: { onSelect(project, conversation) }) {
                                conversationRow(conversation, projectName: project.name)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }

                ForEach(projectStore.projects) { project in
                    Section(project.name) {
                        ForEach(project.conversations.filter { !openInOtherWindows.contains($0.id) }) { conversation in
                            Button(action: { onSelect(project, conversation) }) {
                                conversationRow(conversation, projectName: nil)
                            }
                            .foregroundColor(.primary)
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
    private func conversationRow(_ conversation: Conversation, projectName: String?) -> some View {
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
                if let projectName {
                    Text(projectName)
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
}
