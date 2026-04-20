import SwiftUI

struct SettingsViewThemePicker: View {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle

    private let columns = [
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.s),
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.s)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: ThemeTokens.Spacing.m) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    SettingsViewThemePickerCard(theme: theme, isSelected: selectedTheme == theme)
                        .onTapGesture { selectedTheme = theme }
                }
            }
            .padding(ThemeTokens.Spacing.m)
        }
        .themedNavChrome()
    }
}

private struct SettingsViewThemePickerCard: View {
    let theme: Theme
    let isSelected: Bool

    var body: some View {
        let palette = theme.palette
        VStack(spacing: 0) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                ForEach([palette.background, palette.surface, palette.elevated], id: \.self) { color in
                    RoundedRectangle(cornerRadius: ThemeTokens.Radius.s)
                        .fill(color)
                        .frame(height: ThemeTokens.Size.l)
                }
            }
            .padding(ThemeTokens.Spacing.s)

            Text(theme.rawValue)
                .appFont(size: ThemeTokens.Text.l, weight: isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.bottom, ThemeTokens.Spacing.s)
        }
        .cornerRadius(ThemeTokens.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.Radius.m)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: ThemeTokens.Stroke.l)
        )
    }
}
