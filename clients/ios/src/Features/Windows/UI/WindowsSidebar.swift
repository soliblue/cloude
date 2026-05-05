import SwiftData
import SwiftUI

struct WindowsSidebar: View {
    @Binding var selectedPane: WindowsPane
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("ws.body")
        NavigationStack {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                        if !windows.isEmpty {
                            sectionHeader("Open")
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(windows) { window in
                                    if let session = window.session {
                                        WindowsSidebarOpenRow(
                                            session: session,
                                            isFocused: window.isFocused,
                                            canClose: windows.count > 1,
                                            onActivate: { activate(window) },
                                            onClose: { close(window) }
                                        )
                                    }
                                }
                            }
                        }

                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    SettingsViewEndpoints()
                    DaemonUpdateSettingsRow()
                    SettingsViewTheme()
                    SettingsToggleRow(
                        icon: "ant.fill", color: ThemeColor.orange, title: "Debug Overlay",
                        key: StorageKey.debugOverlayEnabled)
                }
                .padding(.horizontal, ThemeTokens.Spacing.l)
                .padding(.vertical, ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(theme.palette.surface.ignoresSafeArea(edges: .bottom))
            }
            .padding(.top, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.palette.background)
            .themedNavChrome()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private func activate(_ window: Window) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            WindowActions.activate(window, among: windows)
            selectedPane = window.session?.tab == .git ? .git : .session
        }
    }

    private func close(_ window: Window) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            WindowActions.close(window, among: windows, context: context)
        }
    }

}
