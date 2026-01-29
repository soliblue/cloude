//
//  ConversationListView.swift
//  Cloude
//
//  List of conversations with swipe actions
//

import SwiftUI

struct ConversationListView: View {
    @ObservedObject var store: ConversationStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingConversation: Conversation?
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(store.conversations) { conversation in
                ConversationRow(
                    conversation: conversation,
                    isSelected: store.currentConversation?.id == conversation.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    store.select(conversation)
                    dismiss()
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.delete(conversation)
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
        .listStyle(.plain)
        .overlay {
            if store.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new conversation to begin")
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
                    store.rename(conv, to: newName)
                }
                editingConversation = nil
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isSelected ? Color.blue : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)

                HStack(spacing: 8) {
                    Text("\(conversation.messages.count) messages")
                    Text(conversation.lastMessageAt, style: .relative)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
