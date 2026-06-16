import SwiftData
import SwiftUI

struct GitView: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var statuses: [GitStatus]
    @Query private var commits: [GitCommit]
    @State private var selectedChange: GitDiffTarget?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @AppStorage(StorageKey.gitViewAsTree) private var viewAsTree = true
    @State private var collapsedStaged: Set<String> = []
    @State private var collapsedUnstaged: Set<String> = []
    @State private var changeCache = GitChangeSectionCache()

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
    }

    @ViewBuilder
    private var content: some View {
        if let status = statuses.first {
            let sections = changeCache.sections(for: status.changes)
            VStack(spacing: 0) {
                GitViewStatusHeader(summary: GitStatusSummary(status: status), session: session)
                if sections.isEmpty {
                    commitsList
                } else {
                    changesList(sections)
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

    private func changesList(_ sections: GitChangeSections) -> some View {
        List {
            if !sections.staged.isEmpty {
                Section("Staged") {
                    changeRows(
                        changes: sections.staged,
                        tree: sections.stagedTree,
                        collapsed: $collapsedStaged
                    )
                }
            }
            if !sections.unstaged.isEmpty {
                Section("Changes") {
                    changeRows(
                        changes: sections.unstaged,
                        tree: sections.unstagedTree,
                        collapsed: $collapsedUnstaged
                    )
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
    private func changeRows(
        changes: [GitChange], tree: [GitChangeTreeNode], collapsed: Binding<Set<String>>
    ) -> some View {
        if viewAsTree {
            ForEach(tree) { node in
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
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
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
