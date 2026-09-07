import SwiftData
import SwiftUI

struct WindowsSidebar: View {
    @Binding var selectedPane: WindowsPane
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]
    @Query(sort: \Session.lastOpenedAt, order: .reverse) private var sessions: [Session]
    @State private var search = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                HStack {
                    Text("Afto")
                        .appFont(size: ThemeTokens.Text.xxl, weight: .semibold)
                    Spacer()
                    Button {
                        _ = WindowActions.addNew(into: context, after: windows)
                        selectedPane = .session
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .appFont(size: ThemeTokens.Text.xl, weight: .medium)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("New task")
                }
                .padding(.horizontal, ThemeTokens.Spacing.l)
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search tasks, folders, hosts", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search tasks, folders, and hosts")
                }
                .appFont(size: ThemeTokens.Text.m)
                .padding(ThemeTokens.Spacing.m)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                .padding(.horizontal, ThemeTokens.Spacing.l)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                        ForEach(WindowsSidebarSection.allCases) { section in
                            let matches = section.sessions(from: sessions, search: search)
                            if !matches.isEmpty {
                                HStack {
                                    Text(section.rawValue)
                                    Spacer()
                                    Text(matches.count, format: .number)
                                }
                                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                                .foregroundColor(ThemeColor.secondary)
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
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(
                                            session.isPinned ? "Unpin" : "Pin",
                                            systemImage: session.isPinned ? "pin.slash" : "pin"
                                        ) {
                                            SessionActions.setPinned(session, !session.isPinned)
                                        }
                                        if let window = windows.first(where: { $0.session?.id == session.id }),
                                            windows.count > 1
                                        {
                                            Button("Close tab", systemImage: "xmark") {
                                                WindowActions.close(window, among: windows, context: context)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ThemeTokens.Spacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    SettingsViewEndpoints()
                    DaemonUpdateSettingsRow()
                    SettingsViewTheme()
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
}
