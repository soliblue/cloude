import SwiftData
import SwiftUI

struct WindowsSidebar: View {
    @Binding var isOpen: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]
    @Query(sort: \Session.lastOpenedAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @State private var isCreatingEndpoint = false

    var body: some View {
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

                        if !remaining.isEmpty {
                            sectionHeader("Recent")
                            ForEach(remaining) { session in
                                HStack(spacing: ThemeTokens.Spacing.s) {
                                    WindowsSidebarRow(
                                        symbol: session.symbol,
                                        title: session.title,
                                        isFocused: false
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(session) }
                                    Spacer(minLength: 0)
                                    Button {
                                        delete(session)
                                    } label: {
                                        Image(systemName: "trash")
                                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                                            .foregroundColor(.secondary)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    sectionHeader("Endpoints")
                    ForEach(endpoints) { endpoint in
                        NavigationLink {
                            EndpointView(existing: endpoint, canDelete: endpoints.count > 1)
                        } label: {
                            HStack(spacing: ThemeTokens.Spacing.s) {
                                WindowsSidebarRow(
                                    symbol: endpoint.symbolName,
                                    title: endpoint.host.isEmpty ? "New Endpoint" : endpoint.host,
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
                    Button {
                        isCreatingEndpoint = true
                    } label: {
                        WindowsSidebarRow(
                            symbol: "plus",
                            title: "Add Endpoint",
                            isFocused: false
                        )
                    }
                    .buttonStyle(.plain)

                    sectionHeader("Settings")
                    SettingsViewAccent()
                    SettingsViewTheme()
                    SettingsViewFontSize()
                    SettingsToggleRow(
                        icon: "text.word.spacing", color: ThemeColor.cyan, title: "Wrap Code Lines",
                        key: StorageKey.wrapCodeLines)
                    SettingsToggleRow(
                        icon: "ant.fill", color: ThemeColor.orange, title: "Debug Overlay",
                        key: StorageKey.debugOverlayEnabled)
                    SettingsViewAbout()
                    Button {
                        isOpen = false
                        NotificationCenter.default.post(name: .openOnboarding, object: nil)
                    } label: {
                        SettingsRow(icon: "sparkles", color: ThemeColor.purple) {
                            Text("Onboarding")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
            .navigationDestination(isPresented: $isCreatingEndpoint) {
                EndpointView(existing: nil, canDelete: false)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private var remaining: [Session] {
        let openIds = Set(windows.compactMap { $0.session?.id })
        return sessions.filter { !openIds.contains($0.id) }
    }

    private func activate(_ window: Window) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            WindowActions.activate(window, among: windows)
            isOpen = false
        }
    }

    private func close(_ window: Window) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            WindowActions.close(window, among: windows, context: context)
        }
    }

    private func delete(_ session: Session) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            SessionActions.delete(session, context: context)
        }
    }

    private func open(_ session: Session) {
        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
            WindowActions.open(session, among: windows, context: context)
            isOpen = false
        }
    }
}
