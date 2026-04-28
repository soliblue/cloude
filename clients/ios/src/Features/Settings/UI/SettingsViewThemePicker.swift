import SwiftUI

struct SettingsViewThemePicker: View {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle
    @AppStorage(StorageKey.appAccent) private var selectedAccent: AppAccent = .clay
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps
    @AppStorage(StorageKey.typewriterFadeWindow) private var fadeWindow: Double = TypewriterDefaults
        .fadeWindow

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                sectionHeader("Theme")
                VStack(spacing: 0) {
                    ForEach(Array(Theme.allCases.enumerated()), id: \.element) { index, theme in
                        if index > 0 { Divider() }
                        SettingsViewThemePickerThemeRow(
                            theme: theme, isSelected: selectedTheme == theme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTheme = theme }
                    }
                }

                sectionHeader("Accent")
                VStack(spacing: 0) {
                    ForEach(Array(AppAccent.allCases.enumerated()), id: \.element) { index, accent in
                        if index > 0 { Divider() }
                        SettingsViewThemePickerAccentRow(
                            accent: accent, isSelected: selectedAccent == accent
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedAccent = accent }
                    }
                }

                sectionHeader("Font size")
                Stepper("Font size", value: $fontSizeStep, in: 0...3)
                    .padding(.vertical, ThemeTokens.Spacing.s)

                sectionHeader("Typewriter speed")
                sliderRow(
                    value: $cps, range: 10...300, step: 5,
                    formatted: "\(Int(cps)) chars/sec")

                sectionHeader("Typewriter fade")
                sliderRow(
                    value: $fadeWindow, range: 1...80, step: 1,
                    formatted: "\(Int(fadeWindow)) glyphs")
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .themedNavChrome()
    }

    private func sliderRow(
        value: Binding<Double>, range: ClosedRange<Double>, step: Double, formatted: String
    ) -> some View {
        HStack {
            Slider(value: value, in: range, step: step)
            Text(formatted)
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .trailing)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

private struct SettingsViewThemePickerThemeRow: View {
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

private struct SettingsViewThemePickerAccentRow: View {
    let accent: AppAccent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Circle()
                .fill(accent.color)
                .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
            Text(accent.rawValue)
                .appFont(size: ThemeTokens.Text.m, weight: isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            }
        }
        .padding(.vertical, ThemeTokens.Spacing.m)
    }
}
