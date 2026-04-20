import SwiftUI

struct RootView: View {
    @Environment(\.theme) private var theme
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.palette.background.ignoresSafeArea()
            Button { isSettingsPresented = true } label: {
                SettingsButton()
            }
            .padding(.leading, ThemeTokens.Spacing.m)
            .padding(.top, ThemeTokens.Spacing.s)
            DebugOverlay()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .preferredColorScheme(theme.palette.colorScheme)
    }
}
