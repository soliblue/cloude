import SwiftUI

struct SessionEmptyViewPickerRow<Options: View>: View {
    let icon: String
    let title: String
    let value: String
    @ViewBuilder let options: Options

    var body: some View {
        Menu {
            options
        } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: icon)
                    .appFont(size: ThemeTokens.Text.l)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(ThemeColor.secondary)
                    Text(value)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .foregroundColor(ThemeColor.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
