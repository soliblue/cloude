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
                Text(DateFormatters.relativeTime(lastMessageAt))
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
