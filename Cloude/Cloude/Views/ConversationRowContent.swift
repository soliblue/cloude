import SwiftUI

struct ConversationRowContent: View {
    let symbol: String?
    let name: String
    let messageCount: Int
    let lastMessageAt: Date
    var envSymbol: String?
    var searchSnippet: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.s) {
                Image.safeSymbol(symbol)
                Text(name)
                    .lineLimit(1)
                Circle()
                    .fill(Color.secondary.opacity(DS.Opacity.m))
                    .frame(width: DS.Size.s, height: DS.Size.s)
                Text("\(messageCount) msgs")
                Circle()
                    .fill(Color.secondary.opacity(DS.Opacity.m))
                    .frame(width: DS.Size.s, height: DS.Size.s)
                Text(relativeTime(lastMessageAt))
                Spacer()
                if let envSymbol {
                    Image.safeSymbol(envSymbol)
                }
            }

            if let searchSnippet {
                Text(searchSnippet)
                    .lineLimit(2)
            }
        }
        .font(.system(size: DS.Text.m))
        .foregroundColor(.secondary)
    }
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
