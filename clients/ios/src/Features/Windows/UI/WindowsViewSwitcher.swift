import SwiftData
import SwiftUI

struct WindowsViewSwitcher: View {
    @Query(sort: \Window.order) private var windows: [Window]
    @State private var isSettingsPresented = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                SettingsPill(isPresented: $isSettingsPresented)
                ForEach(windows) { window in
                    if let session = window.session {
                        WindowsViewSwitcherPill(window: window, session: session, windows: windows)
                    }
                }
                WindowsViewSwitcherAddPill(windows: windows)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deeplinkOpenSettings)) { _ in
            isSettingsPresented = true
        }
    }
}
