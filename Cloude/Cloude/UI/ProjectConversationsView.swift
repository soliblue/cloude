//
//  ProjectConversationsView.swift
//  Cloude
//
//  Shows conversations within a project
//

import SwiftUI

struct ProjectConversationsView: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject var connection: ConnectionManager
    let project: Project
    @Binding var isPresented: Bool

    @State private var editingConversation: Conversation?
    @State private var newName = ""
    @State private var showSettings = false

    private var currentProject: Project {
        store.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var folderName: String {
        if !currentProject.rootDirectory.isEmpty {
            return (currentProject.rootDirectory as NSString).lastPathComponent
        }
        return currentProject.name
    }

    var body: some View {
        List {
            if !currentProject.rootDirectory.isEmpty {
                Section {
                    Label(currentProject.rootDirectory, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(currentProject.conversations) { conversation in
                    ConversationRowView(
                        conversation: conversation,
                        isSelected: store.currentConversation?.id == conversation.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.selectConversation(conversation, in: currentProject)
                        isPresented = false
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteConversation(conversation, from: currentProject)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingConversation = conversation
                            newName = conversation.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if currentProject.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new conversation in this project")
                )
            }
        }
        .alert("Rename Conversation", isPresented: .init(
            get: { editingConversation != nil },
            set: { if !$0 { editingConversation = nil } }
        )) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {
                editingConversation = nil
            }
            Button("Save") {
                if let conv = editingConversation {
                    renameConversation(conv, to: newName)
                }
                editingConversation = nil
            }
        }
        .sheet(isPresented: $showSettings) {
            ProjectSettingsSheet(store: store, connection: connection, project: currentProject, isPresented: $showSettings)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    Button(action: {
                        let workingDir = currentProject.rootDirectory.isEmpty ? nil : currentProject.rootDirectory
                        _ = store.newConversation(in: currentProject, workingDirectory: workingDir)
                        isPresented = false
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func renameConversation(_ conversation: Conversation, to name: String) {
        guard let projectIndex = store.projects.firstIndex(where: { $0.id == project.id }),
              let convIndex = store.projects[projectIndex].conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        store.projects[projectIndex].conversations[convIndex].name = name
    }
}
