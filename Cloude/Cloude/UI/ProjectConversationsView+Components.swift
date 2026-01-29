//
//  ProjectConversationsView+Components.swift
//  Cloude
//

import SwiftUI

struct ConversationRowView: View {
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
