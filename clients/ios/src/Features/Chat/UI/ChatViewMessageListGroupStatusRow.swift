import SwiftUI

struct ChatViewMessageListGroupStatusRow: View {
    let modelId: String
    let costUsd: Double?

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: friendly?.model.symbol ?? "cpu")
            Text(friendly?.name ?? modelId)
            if let costUsd {
                Text("·")
                Text(String(format: "$%.4f", costUsd))
                    .monospacedDigit()
            }
        }
        .appFont(size: ThemeTokens.Text.s)
        .foregroundStyle(.secondary)
        .opacity(ThemeTokens.Opacity.l)
    }

    private var friendly: (model: ChatModel, name: String)? {
        ChatModel.friendly(fromId: modelId)
    }
}
