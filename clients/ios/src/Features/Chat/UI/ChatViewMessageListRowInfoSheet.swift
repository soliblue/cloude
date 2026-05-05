import SwiftUI

struct ChatViewMessageListRowInfoSheet: View {
    let message: ChatMessage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private var rows: [(String, String)] {
        var result: [(String, String)] = [
            ("clock", message.createdAt.formatted(date: .abbreviated, time: .shortened))
        ]
        if let model = message.model {
            result.append(("cpu", model))
        }
        if let costUsd = message.costUsd {
            result.append(("dollarsign.circle", String(format: "$%.4f", costUsd)))
        }
        result.append(("textformat.size", "\(message.text.count) chars"))
        if !message.toolCalls.isEmpty {
            result.append(("wrench", "\(message.toolCalls.count) tool calls"))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider() }
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Image(systemName: row.0)
                            .appFont(size: ThemeTokens.Text.s)
                            .foregroundColor(.secondary)
                        Text(row.1)
                            .appFont(size: ThemeTokens.Text.m)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                    .padding(.vertical, ThemeTokens.Spacing.m)
                }
                Spacer()
            }
            .background(theme.palette.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .themedNavChrome()
        }
        .presentationDetents([.medium])
        .presentationBackground(theme.palette.background)
    }
}
