import SwiftUI

struct SettingsViewThemePicker: View {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(Theme.allCases.enumerated()), id: \.element) { index, theme in
                    if index > 0 { Divider() }
                    SettingsViewThemePickerRow(theme: theme, isSelected: selectedTheme == theme)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTheme = theme }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
        .themedNavChrome()
    }
}

private struct SettingsViewThemePickerRow: View {
    let theme: Theme
    let isSelected: Bool

    var body: some View {
        let palette = theme.palette
        HStack(spacing: ThemeTokens.Spacing.m) {
            Text(theme.rawValue)
                .appFont(size: ThemeTokens.Text.m, weight: isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer()
            HStack(spacing: ThemeTokens.Spacing.xs) {
                ForEach([palette.background, palette.surface, palette.elevated], id: \.self) { color in
                    RoundedRectangle(cornerRadius: ThemeTokens.Radius.s)
                        .fill(color)
                        .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
                }
            }
        }
        .padding(.vertical, ThemeTokens.Spacing.m)
    }
}
