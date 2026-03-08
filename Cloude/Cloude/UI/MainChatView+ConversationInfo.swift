import SwiftUI
import CloudeShared

struct ConversationInfoLabel: View {
    let conversation: Conversation?
    var showCost: Bool = false
    var placeholderText: String = "Select conversation..."

    var body: some View {
        HStack(spacing: 5) {
            Image.safeSymbol(conversation?.symbol)
                .font(.system(size: 15))
                .contentTransition(.symbolEffect(.replace))
            if let conv = conversation {
                Text(conv.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: conv.name)
            } else {
                Text(placeholderText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                Text("• \(folder)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if showCost, let conv = conversation, conv.totalCost > 0 {
                Text("• $\(String(format: "%.2f", conv.totalCost))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct WindowHeaderView: View {
    let conversation: Conversation?
    let onSelectConversation: (() -> Void)?

    var body: some View {
        Button(action: { onSelectConversation?() }) {
            HStack(spacing: 6) {
                ConversationInfoLabel(conversation: conversation)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.oceanSecondary)
        }
        .buttonStyle(.plain)
    }
}
