import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.palette.background.ignoresSafeArea()
            ZStack {
                ForEach(windows) { window in
                    if let session = window.session {
                        SessionView(session: session)
                            .opacity(window.isFocused ? 1 : 0)
                            .allowsHitTesting(window.isFocused)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                WindowsViewSwitcher()
                    .padding(.vertical, ThemeTokens.Spacing.s)
            }
            Button {
                isSettingsPresented = true
            } label: {
                SettingsButton()
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
            DebugOverlay()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .preferredColorScheme(theme.palette.colorScheme)
    }
}
