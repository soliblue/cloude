import SwiftData
import SwiftUI

struct WindowsSidebar: View {
    @Binding var selectedPane: WindowsPane
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @Query(sort: \Window.order) private var windows: [Window]
    @Query(sort: \Session.lastOpenedAt, order: .reverse) private var sessions: [Session]
    @State private var search = ""
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                if showingSearch {
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search tasks, folders, and hosts")
                        Button {
                            search = ""
                            showingSearch = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close search")
                    }
                    .appFont(size: ThemeTokens.Text.m)
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                    .frame(minHeight: 44)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                        ForEach(WindowsSidebarSection.allCases) { section in
                            let matches = section.sessions(from: sessions, search: search)
                            if !matches.isEmpty {
                                Text(section.rawValue)
                                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                                    .foregroundColor(ThemeColor.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, ThemeTokens.Spacing.m)
                                ForEach(matches) { session in
                                    Button {
                                        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                                            WindowActions.open(session, among: windows, context: context)
                                            selectedPane = .session
                                        }
                                    } label: {
                                        WindowsSidebarRow(
                                            symbol: session.needsAttention ? "hand.raised" : session.symbol,
                                            title: session.title,
                                            isFocused: windows.contains {
                                                $0.isFocused && $0.session?.id == session.id
                                            },
                                            isStreaming: (session.isStreaming || session.remoteIsRunning)
                                                && !session.needsAttention,
                                            isUnread: session.hasUnread,
                                            needsAttention: session.needsAttention,
                                            endpointName: session.endpoint?.displayName,
                                            path: session.path
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, ThemeTokens.Spacing.s)
                                        .padding(.horizontal, ThemeTokens.Spacing.l)
                                        .background(
                                            windows.contains { $0.isFocused && $0.session?.id == session.id }
                                                ? appAccent.color.opacity(0.15) : Color.clear
                                        )
                                        .padding(.horizontal, -ThemeTokens.Spacing.l)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .modifier(
                                        SessionTaskActionsModifier(
                                            session: session,
                                            closeTab: windows.count > 1
                                                && windows.contains { $0.session?.id == session.id }
                                                ? {
                                                    if let window = windows.first(where: {
                                                        $0.session?.id == session.id
                                                    }) {
                                                        WindowActions.close(window, among: windows, context: context)
                                                    }
                                                } : nil
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
                HStack(spacing: ThemeTokens.Spacing.l) {
                    NavigationLink {
                        SettingsView(selectedPane: $selectedPane)
                    } label: {
                        SettingsRow(icon: "gearshape", color: ThemeColor.secondary) {
                            Text("Settings")
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    Button {
                        showingSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Search chats")
                    Button {
                        _ = WindowActions.addNew(into: context, after: windows)
                        selectedPane = .session
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("New task")
                }
                .appFont(size: ThemeTokens.Text.l)
                .foregroundColor(ThemeColor.secondary)
                .padding(.horizontal, ThemeTokens.Spacing.l)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .background(theme.palette.surface.ignoresSafeArea(edges: .bottom))
            }
            .padding(.top, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.palette.background)
            .themedNavChrome()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: windows.first(where: { $0.isFocused })?.session?.id) { _, id in
                if id != nil && selectedPane == .sidebar { selectedPane = .session }
            }
        }
    }
}
