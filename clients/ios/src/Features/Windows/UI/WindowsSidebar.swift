import SwiftData
import SwiftUI

struct WindowsSidebar: View {
    @Binding var selectedPane: WindowsPane
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]

    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("ws.body")
        NavigationStack {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                        if !windows.isEmpty {
                            sectionHeader("Open")
                            ForEach(windows) { window in
                                if let session = window.session {
                                    HStack(spacing: ThemeTokens.Spacing.s) {
                                        WindowsSidebarRow(
                                            symbol: session.symbol,
                                            title: session.title,
                                            isFocused: window.isFocused
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture { activate(window) }
                                        Spacer(minLength: 0)
                                        WindowsSidebarOpenRowStatus(
                                            session: session,
                                            isFocused: window.isFocused,
                                            canClose: windows.count > 1,
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
                    HStack {
                        sectionHeader("Endpoints")
                        Spacer()
                        Button {
                            selectedPane = .session
                            NotificationCenter.default.post(name: .openOnboarding, object: OnboardingStep.pair)
                        } label: {
                            Image(systemName: "plus")
                                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                                .foregroundColor(.secondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(endpoints) { endpoint in
                        NavigationLink {
                            EndpointView(existing: endpoint, canDelete: endpoints.count > 1)
                        } label: {
                            HStack(spacing: ThemeTokens.Spacing.s) {
                                WindowsSidebarRow(
                                    symbol: endpoint.symbolName,
                                    title: endpoint.displayName,
                                    isFocused: false
                                )
                                Spacer(minLength: 0)
                                if let reachable = endpoint.lastCheckReachable {
                                    Circle()
                                        .fill(reachable ? ThemeColor.success : ThemeColor.danger)
                                        .frame(width: ThemeTokens.Size.s, height: ThemeTokens.Size.s)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    sectionHeader("Settings")
                    SettingsViewTheme()
                    SettingsViewFontSize()
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
