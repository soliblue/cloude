import SwiftUI
import CloudeShared

struct GitChangesView: View {
    let connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?
    @ObservedObject var state: GitChangesState

    @State private var selectedFile: GitFileStatus?
    @State private var pendingRepoPath: String?

    private var defaultWorkingDirectory: String? {
        connection.connection(for: environmentId)?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRepoPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var repoPath: String {
        resolvedRepoPath ?? "~"
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isInitialLoad && state.gitStatus == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = state.gitStatus {
                statusHeader(status)
                if status.hasChanges {
                    filesList(status.files)
                } else {
                    commitsList
                }
            } else {
                ContentUnavailableView("No Repository", systemImage: "folder.badge.questionmark", description: Text("Not a git repository"))
            }
        }
        .sheet(item: $selectedFile) { file in
            GitDiffView(connection: connection, repoPath: repoPath, file: file, environmentId: environmentId)
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: resolvedRepoPath) { oldValue, newValue in
            if oldValue != newValue {
                resetAndLoad()
            }
        }
        .refreshable { loadStatus() }
        .onReceive(connection.events) { event in
            if case let .gitStatus(path, status, envId) = event, path == repoPath, envId == environmentId {
                state.applyStatus(status)
                AppLogger.endInterval("git.status", key: pendingRepoPath ?? path, details: "files=\(status.files.count)")
                pendingRepoPath = nil
                if !status.hasChanges {
                    connection.gitLog(path: path, environmentId: environmentId)
                }
            } else if case let .gitStatusError(path, _, envId) = event, path == repoPath, envId == environmentId {
                state.applyError()
                AppLogger.cancelInterval("git.status", key: pendingRepoPath ?? path, reason: "error")
                pendingRepoPath = nil
            } else if case let .gitLog(path, commits, envId) = event, path == repoPath, envId == environmentId {
                state.applyCommits(commits)
            }
        }
    }

    private func loadIfNeeded() {
        if state.isInitialLoad {
            loadStatus()
        } else {
            refreshInBackground()
        }
    }

    private func resetAndLoad() {
        state.reset()
        loadStatus()
    }

    private func refreshInBackground() {
        guard let repoPath = resolvedRepoPath else { return }
        state.beginLoading()
        pendingRepoPath = repoPath
        connection.gitStatus(path: repoPath, environmentId: environmentId)
    }

    private func loadStatus() {
        guard let repoPath = resolvedRepoPath else {
            pendingRepoPath = nil
            state.reset()
            return
        }

        if let conn = connection.connection(for: environmentId) {
            if conn.gitStatusInFlightPath != nil {
                conn.gitStatusTimeoutTask?.cancel()
                conn.gitStatusInFlightPath = nil
            }
        }
        state.beginLoading()
        pendingRepoPath = repoPath
        AppLogger.beginInterval("git.status", key: repoPath)
        connection.gitStatus(path: repoPath, environmentId: environmentId)
    }

    private func statusHeader(_ status: GitStatusInfo) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Text(status.branch)
                .font(.system(size: DS.Text.m, weight: .semibold))

            if status.ahead > 0 {
                Label("\(status.ahead)", systemImage: "arrow.up")
            }
            if status.behind > 0 {
                Label("\(status.behind)", systemImage: "arrow.down")
            }

            Spacer()

            let totalAdd = status.files.compactMap(\.additions).reduce(0, +)
            let totalDel = status.files.compactMap(\.deletions).reduce(0, +)
            if totalAdd > 0 || totalDel > 0 {
                HStack(spacing: DS.Spacing.xs) {
                    if totalAdd > 0 {
                        Text("+\(totalAdd)")
                            .foregroundColor(AppColor.success)
                    }
                    if totalDel > 0 {
                        Text("-\(totalDel)")
                            .foregroundColor(AppColor.danger)
                    }
                }
                .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                Text("·")
                    .foregroundColor(.secondary)
            }

            if !status.stagedFiles.isEmpty {
                Text("\(status.stagedFiles.count) staged")
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(AppColor.success)
                Text("·")
                    .foregroundColor(.secondary)
            }
            Text("\(status.unstagedFiles.count) changed")
                .font(.system(size: DS.Text.s, weight: .medium))
                .foregroundColor(status.hasChanges ? AppColor.orange : AppColor.success)
        }
        .font(.system(size: DS.Text.s))
        .foregroundColor(.secondary)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .background(Color.themeSecondary)
    }

    private var commitsList: some View {
        Group {
            if state.recentCommits.isEmpty {
                ContentUnavailableView("No Changes", systemImage: "checkmark.circle", description: Text("Working tree clean"))
            } else {
                List {
                    Section {
                        ForEach(state.recentCommits) { commit in
                            GitCommitRow(commit: commit)
                                .listRowBackground(Color.themeBackground)
                        }
                    } header: {
                        Text("Recent Commits")
                            .font(.system(size: DS.Text.s, weight: .semibold))
                            .textCase(.uppercase)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
    }

    private func filesList(_ files: [GitFileStatus]) -> some View {
        let staged = files.filter { $0.staged }
        let unstaged = files.filter { !$0.staged }
        return List {
            if !staged.isEmpty {
                Section {
                    ForEach(staged) { file in
                        GitFileRow(file: file) { selectedFile = file }
                            .listRowBackground(Color.themeBackground)
                    }
                } header: {
                    Text("Staged")
                        .font(.system(size: DS.Text.s, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
            if !unstaged.isEmpty {
                Section {
                    ForEach(unstaged) { file in
                        GitFileRow(file: file) { selectedFile = file }
                            .listRowBackground(Color.themeBackground)
                    }
                } header: {
                    Text("Changes")
                        .font(.system(size: DS.Text.s, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
