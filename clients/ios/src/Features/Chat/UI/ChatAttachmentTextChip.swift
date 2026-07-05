import SwiftUI

struct ChatAttachmentTextChip: View {
    let text: String

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Image(systemName: "doc.plaintext")
                .appFont(size: ThemeTokens.Text.m)
                .foregroundStyle(ThemeColor.secondary)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                Text("Pasted text")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                Text("\(text.count.formatted()) chars")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundStyle(ThemeColor.secondary)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .frame(height: ThemeTokens.Size.l)
        .glassEffect(
            .regular.interactive(), in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
    }
}
