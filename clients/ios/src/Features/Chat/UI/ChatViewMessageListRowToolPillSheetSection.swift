import SwiftUI

struct ChatViewMessageListRowToolPillSheetSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label(title, systemImage: icon)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundColor(.secondary)
            content()
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        }
    }
}
