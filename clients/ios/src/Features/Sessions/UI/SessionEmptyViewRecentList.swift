import SwiftData
import SwiftUI

struct SessionEmptyViewRecentList: View {
    let currentSession: Session
    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @Query private var windows: [Window]

    init(currentSession: Session) {
        self.currentSession = currentSession
        let currentId = currentSession.id
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id != currentId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        _sessions = Query(descriptor)
    }

    var body: some View {
        let visible = filtered
        if !visible.isEmpty {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("Recent")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.top, ThemeTokens.Spacing.m)
                .padding(.bottom, ThemeTokens.Spacing.xs)
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                    SessionEmptyViewRecentListRow(session: session) {
                        swap(to: session)
                    }
                    if index < visible.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var filtered: [Session] {
        let openIds = Set(windows.compactMap { $0.session?.id })
        return
            sessions
            .lazy
            .filter { !openIds.contains($0.id) }
            .prefix(5)
            .map { $0 }
    }

    private func swap(to target: Session) {
        if let window = windows.first(where: { $0.session?.id == currentSession.id }) {
            WindowActions.swap(window, to: target, context: context)
        }
    }
}
