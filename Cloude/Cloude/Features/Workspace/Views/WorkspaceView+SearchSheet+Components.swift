import SwiftUI
import CloudeShared

extension ConversationSearchSheet {
    func conversationRow(_ conv: Conversation) -> some View {
        ConversationRowContent(
            symbol: conv.symbol,
            name: conv.name,
            messageCount: conv.messages.count,
            lastMessageAt: conv.lastMessageAt,
            searchSnippet: searchText.isEmpty ? nil : firstMessageMatch(conv)
        )
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.m)
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

}
