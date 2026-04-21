import SwiftUI

struct SessionViewTabs: View {
    @Binding var selected: SessionTab
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            ForEach(SessionTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    HStack(spacing: ThemeTokens.Spacing.xs) {
                        Image(systemName: tab.symbol)
                            .appFont(size: ThemeTokens.Icon.m)
                        Text(tab.label)
                            .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    }
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .foregroundColor(selected == tab ? Color.accentColor : .secondary)
                    .background(selected == tab ? Color.accentColor.opacity(ThemeTokens.Opacity.s) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .frame(height: ThemeTokens.Size.l)
    }
}
