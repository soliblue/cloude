import SwiftUI

struct SettingsRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: icon)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(color)
                .frame(width: ThemeTokens.Size.m)
            content
                .appFont(size: ThemeTokens.Text.l)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    @AppStorage var isOn: Bool

    init(icon: String, color: Color, title: String, key: String) {
        self.icon = icon
        self.color = color
        self.title = title
        self._isOn = AppStorage(wrappedValue: false, key)
    }

    var body: some View {
        SettingsRow(icon: icon, color: color) {
            Toggle(title, isOn: $isOn)
        }
    }
}
