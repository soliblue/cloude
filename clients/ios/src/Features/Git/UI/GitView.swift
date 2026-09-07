import SwiftData
import SwiftUI

struct GitView: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var statuses: [GitStatus]
    @Query private var commits: [GitCommit]
    @State private var selectedChange: GitDiffTarget?
    @State private var selectedCommit: GitCommitTarget?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var isCommitPresented = false
    @State private var isLoadingMore = false
    @State private var hasMoreCommits = true
    @State private var historyFailed = false
    @AppStorage(StorageKey.gitViewAsTree) private var viewAsTree = true
    @State private var collapsedStaged: Set<String> = []
    @State private var collapsedUnstaged: Set<String> = []

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
            .sheet(item: $selectedChange) { target in
                GitDiffSheet(session: session, target: target)
            }
            .sheet(item: $selectedCommit) { target in
                GitCommitDetailView(session: session, sha: target.sha)
            }
            .sheet(isPresented: $isCommitPresented) {
                GitCommitSheet(session: session, fileCount: statuses.first?.changes.filter(\.isStaged).count ?? 0)
            }
            .alert("Could not load more history", isPresented: $historyFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your saved commits are still available. Check your connection and try again.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let status = statuses.first {
            VStack(spacing: 0) {
                GitViewStatusHeader(status: status, session: session)
                if status.changes.isEmpty && commits.isEmpty {
                    ContentUnavailableView(
                        "No Commits",
                        systemImage: "checkmark.circle",
                        description: Text("Working tree clean")
                    )
                } else {
                    changesAndCommitsList(status.changes)
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

    private func changesAndCommitsList(_ changes: [GitChange]) -> some View {
        let sorted = changes.sorted { $0.path < $1.path }
        let staged = sorted.filter(\.isStaged)
        let unstaged = sorted.filter { !$0.isStaged }
        return List {
            if !staged.isEmpty {
                Section("Staged") {
                    changeRows(staged, collapsed: $collapsedStaged)
                    if session.endpoint?.supportsGitMutations == true {
                        Button("Commit staged changes", systemImage: "checkmark.circle") {
                            isCommitPresented = true
                        }
                        .listRowBackground(theme.palette.background)
                    }
                }
            }
            if !unstaged.isEmpty {
                Section("Changes") {
                    changeRows(unstaged, collapsed: $collapsedUnstaged)
                }
            }
            if !commits.isEmpty {
                Section("Recent Commits") {
                    ForEach(commits) { commit in
                        GitViewCommitRow(commit: commit) {
                            selectedCommit = GitCommitTarget(sha: commit.sha)
                        }
                        .listRowBackground(theme.palette.background)
                    }
                    if hasMoreCommits && commits.count >= 50 {
                        Button {
                            Task {
                                isLoadingMore = true
                                if let count = await GitService.loadMore(
                                    session: session, count: commits.count, context: context)
                                {
                                    hasMoreCommits = count == 50
                                } else {
                                    historyFailed = true
                                }
                                isLoadingMore = false
                            }
                        } label: {
                            HStack {
                                Text("Load older commits")
                                Spacer()
                                if isLoadingMore { ProgressView() }
                            }
                        }
                        .disabled(isLoadingMore)
                        .listRowBackground(theme.palette.background)
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
    }

    @ViewBuilder
    private func changeRows(_ changes: [GitChange], collapsed: Binding<Set<String>>) -> some View {
        if viewAsTree {
            ForEach(GitChangeTreeNode.build(changes)) { node in
                GitViewChangeTreeRow(node: node, depth: 0, collapsed: collapsed) { change in
                    selectedChange = GitDiffTarget(path: change.path, isStaged: change.isStaged)
                }
                .listRowBackground(theme.palette.background)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: 0, leading: ThemeTokens.Spacing.l, bottom: 0,
                        trailing: ThemeTokens.Spacing.l))
            }
        } else {
            ForEach(changes) { change in
                GitViewChangeRow(change: change) {
                    selectedChange = GitDiffTarget(path: change.path, isStaged: change.isStaged)
                }
                .listRowBackground(theme.palette.background)
            }
        }
    }

    private func refresh() async {
        if session.endpoint != nil, session.path != nil {
            isLoading = true
            await GitService.refresh(session: session, context: context)
            hasMoreCommits = true
            isLoading = false
        }
    }
}
