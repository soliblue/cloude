import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @Binding var selectedPane: WindowsPane
    @State private var showArchived = false
    @State private var archiveFailed = false
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.lastOpenedAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \Window.order) private var windows: [Window]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Toggle("Archived chats", isOn: $showArchived).padding(.vertical, ThemeTokens.Spacing.m)
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No history yet", systemImage: "clock",
                        description: Text("Sessions you open will show up here.")
                    )
                    .padding(.top, ThemeTokens.Spacing.xl)
                }
                ForEach(Array(sessions.filter { $0.isArchived == showArchived }.enumerated()), id: \.element.id) {
                    index, session in
                    if index > 0 { Divider() }
                    Button {
                        open(session)
                    } label: {
                        WindowsSidebarRow(
                            symbol: session.symbol,
                            title: session.title,
                            isFocused: false,
                            endpointName: session.endpoint?.displayName,
                            path: session.path
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(session.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                            Task {
                                archiveFailed =
                                    !(await SessionService.archive(session: session, archived: !session.isArchived))
                            }
                        }.disabled(session.isStreaming)
                    }
                    .padding(.vertical, ThemeTokens.Spacing.s)
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.l)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .background(theme.palette.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .alert("Could not update this chat", isPresented: $archiveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    private func open(_ session: Session) {
        Task {
            let canOpen = session.isArchived ? await SessionService.archive(session: session, archived: false) : true
            if canOpen {
                withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                    if let window = windows.first(where: { $0.session?.id == session.id }) {
                        WindowActions.activate(window, among: windows)
                    } else {
                        WindowActions.open(session, among: windows, context: context)
                    }
                    selectedPane = session.tab == .git ? .git : .session
                }
                dismiss()
            } else {
                archiveFailed = true
            }
        }
    }
}
