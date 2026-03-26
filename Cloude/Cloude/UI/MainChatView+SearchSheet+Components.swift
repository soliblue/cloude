import SwiftUI
import CloudeShared

extension ConversationSearchSheet {
    func conversationRow(_ conv: Conversation) -> some View {
        HStack(spacing: 10) {
            Image.safeSymbol(conv.symbol)
                .font(.system(size: DS.Text.m))
                .foregroundColor(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(conv.name)
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let dir = conv.workingDirectory, !dir.isEmpty {
                        Text(dir.lastPathComponent)
                            .foregroundColor(.accentColor)
                    }
                    Text("\(conv.messages.count) msgs")
                        .foregroundColor(.secondary)
                    if conv.totalCost > 0 {
                        Text(String(format: "$%.2f", conv.totalCost))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: DS.Text.s))
                if !searchText.isEmpty, let match = firstMessageMatch(conv) {
                    Text(match)
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Text(relativeTime(conv.lastMessageAt))
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    func firstMessageMatch(_ conv: Conversation) -> String? {
        let query = searchText.lowercased()
        if conv.name.lowercased().contains(query) || (conv.workingDirectory?.lowercased().contains(query) ?? false) {
            return nil
        }
        if let msg = conv.messages.first(where: { $0.text.lowercased().contains(query) }) {
            let text = msg.text.replacingOccurrences(of: "\n", with: " ")
            if let range = text.lowercased().range(of: query) {
                let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
                let snippet = String(text[start..<end])
                return (start > text.startIndex ? "..." : "") + snippet + (end < text.endIndex ? "..." : "")
            }
            return String(text.prefix(80)) + (text.count > 80 ? "..." : "")
        }
        return nil
    }

    func relativeTime(_ date: Date) -> String {
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
