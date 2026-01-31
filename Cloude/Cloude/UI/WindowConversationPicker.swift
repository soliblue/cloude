//
//  WindowConversationPicker.swift
//  Cloude

import SwiftUI

struct WindowConversationPicker: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var connection: ConnectionManager
    let onSelect: (Project, Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(projectStore.projects) { project in
                    Section(project.name) {
                        ForEach(project.conversations) { conversation in
                            Button(action: { onSelect(project, conversation) }) {
                                HStack {
                                    if let symbol = conversation.symbol, !symbol.isEmpty {
                                        Image(systemName: symbol)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conversation.name)
                                            .font(.body)
                                        Text("\(conversation.messages.count) messages")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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

    private func createNewConversation(in project: Project) {
        let newConv = projectStore.newConversation(in: project)
        onSelect(project, newConv)
    }

    private func createNewProject(at path: String) {
        let folderName = (path as NSString).lastPathComponent
        let project = projectStore.createProject(name: folderName, rootDirectory: path)
        let conversation = projectStore.newConversation(in: project)
        onSelect(project, conversation)
    }
}
