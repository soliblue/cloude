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
        if let endpoint = session.endpoint, let path = session.path {
            isLoading = true
            async let statusResult = GitService.status(endpoint: endpoint, session: session, path: path)
            async let logResult = GitService.log(endpoint: endpoint, session: session, path: path)
            let (dto, code) = await statusResult
            let commits = await logResult
            if code == 404 {
                SessionActions.setHasGit(false, for: session)
                GitActions.clear(sessionId: session.id, context: context)
            } else {
                SessionActions.setHasGit(true, for: session)
                if let dto {
                    GitActions.upsertStatus(sessionId: session.id, dto: dto, context: context)
                }
                if let commits {
                    GitActions.replaceLog(sessionId: session.id, commits: commits, context: context)
                }
            }
            isLoading = false
        }
    }
}
