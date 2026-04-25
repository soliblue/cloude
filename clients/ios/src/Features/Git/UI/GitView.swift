import SwiftData
import SwiftUI

struct GitView: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var statuses: [GitStatus]
    @Query private var commits: [GitCommit]
    @State private var selectedChange: GitChange?
    @State private var isLoading = false
    @State private var hasLoaded = false

    init(session: Session) {
        self.session = session
        let sessionId = session.id
        _statuses = Query(
            filter: #Predicate<GitStatus> { $0.sessionId == sessionId }
        )
        _commits = Query(
            filter: #Predicate<GitCommit> { $0.sessionId == sessionId },
            sort: \.order
        )
    }

    var body: some View {
        content
            .background(theme.palette.background)
            .task {
                if !hasLoaded {
                    hasLoaded = true
                    await refresh()
                }
            }
            .refreshable { await refresh() }
            .sheet(item: $selectedChange) { change in
                GitDiffSheet(session: session, change: change)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let status = statuses.first {
            VStack(spacing: 0) {
                GitViewStatusHeader(status: status, session: session)
                if status.changes.isEmpty {
                    commitsList
                } else {
                    changesList(status.changes)
                }
            }
        } else if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Repository",
                systemImage: "folder.badge.questionmark",
                description: Text("Not a git repository")
            )
        }
    }

    private func changesList(_ changes: [GitChange]) -> some View {
        let staged = changes.filter(\.isStaged)
        let unstaged = changes.filter { !$0.isStaged }
        return List {
            if !staged.isEmpty {
                Section("Staged") {
                    ForEach(staged) { change in
                        GitViewChangeRow(change: change) { selectedChange = change }
                            .listRowBackground(theme.palette.background)
                    }
                }
            }
            if !unstaged.isEmpty {
                Section("Changes") {
                    ForEach(unstaged) { change in
                        GitViewChangeRow(change: change) { selectedChange = change }
                            .listRowBackground(theme.palette.background)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
    }

    @ViewBuilder
    private var commitsList: some View {
        if commits.isEmpty {
            ContentUnavailableView(
                "No Commits",
                systemImage: "checkmark.circle",
                description: Text("Working tree clean")
            )
        } else {
            List {
                Section("Recent Commits") {
                    ForEach(commits) { commit in
                        GitViewCommitRow(commit: commit)
                            .listRowBackground(theme.palette.background)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
        }
    }

    private func refresh() async {
        if session.endpoint != nil, session.path != nil {
            isLoading = true
            await GitService.refresh(session: session, context: context)
            isLoading = false
        }
    }
}
