import SwiftUI

struct ChatViewMessageListRowToolPillSheetWeb: View {
    let toolCall: ChatToolCall
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let urlString = toolCall.parsedInput["url"] as? String,
                let url = URL(string: urlString)
            {
                Button {
                    openURL(url)
                } label: {
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Image(systemName: "globe")
                            .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                        Text(urlString)
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .appFont(size: ThemeTokens.Text.s)
                    }
                    .foregroundColor(ChatToolKind.web.color)
                    .padding(ThemeTokens.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChatToolKind.web.color.opacity(ThemeTokens.Opacity.s))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
                }
                .buttonStyle(.plain)
            }
            if let query = toolCall.parsedInput["query"] as? String, !query.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Query", icon: "magnifyingglass") {
                    Text(query)
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            if let prompt = toolCall.parsedInput["prompt"] as? String, !prompt.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Prompt", icon: "text.alignleft") {
                    Text(prompt)
                        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
