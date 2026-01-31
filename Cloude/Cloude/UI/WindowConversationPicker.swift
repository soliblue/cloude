//
//  WindowConversationPicker.swift
//  Cloude
//

import SwiftUI

struct WindowConversationPicker: View {
    @ObservedObject var projectStore: ProjectStore
    let onSelect: (Project, Conversation) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(projectStore.projects) { project in
                    Section(project.name) {
                        ForEach(project.conversations) { conversation in
                            Button(action: { onSelect(project, conversation) }) {
                                HStack {
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
                            Label("New Conversation", systemImage: "plus")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func createNewConversation(in project: Project) {
        let newConv = projectStore.newConversation(in: project)
        onSelect(project, newConv)
    }
}
