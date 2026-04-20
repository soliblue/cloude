import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsViewTheme()
                    SettingsViewFontSize()
                    SettingsToggleRow(icon: "text.word.spacing", color: ThemeColor.cyan, title: "Wrap Code Lines", key: StorageKey.wrapCodeLines)
                    SettingsToggleRow(icon: "ant.fill", color: ThemeColor.orange, title: "Debug Overlay", key: StorageKey.debugOverlayEnabled)
                }
                .listRowBackground(theme.palette.surface)
                SettingsViewAbout()
            }
            .contentMargins(.top, ThemeTokens.Spacing.s, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Icon.s, weight: .medium)
                    }
                }
            }
        }
        .preferredColorScheme(theme.palette.colorScheme)
    }
}
