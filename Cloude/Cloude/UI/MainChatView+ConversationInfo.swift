import SwiftUI
import CloudeShared

struct ConversationInfoLabel: View {
    let conversation: Conversation?
    var showCost: Bool = false
    var placeholderText: String = "Select conversation..."

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image.safeSymbol(conversation?.symbol)
                .font(.system(size: DS.Text.m))
                .contentTransition(.symbolEffect(.replace))
            if let conv = conversation {
                Text(conv.name)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: DS.Duration.m), value: conv.name)
            } else {
                Text(placeholderText)
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
            }
            if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                Text("• \(folder)")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if showCost, let conv = conversation, conv.totalCost > 0 {
                Text("• \(conv.totalCost.asCost)")
                    .font(.system(size: DS.Text.s))
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
            HStack(spacing: DS.Spacing.s) {
                ConversationInfoLabel(conversation: conversation)
                Spacer()
            }
            .padding(DS.Spacing.m)
            .background(Color.themeSecondary)
        }
        .buttonStyle(.plain)
    }
}
