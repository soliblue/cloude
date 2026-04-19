import SwiftUI
import CloudeShared

struct GitChangesView: View {
    let environmentStore: EnvironmentStore
    var rootPath: String?
    var environmentId: UUID?
    @ObservedObject var state: GitChangesState
    @Environment(\.appTheme) private var appTheme

    @State private var selectedFile: GitFileStatus?
    @State private var pendingRepoPath: String?

    private var defaultWorkingDirectory: String? {
        connection?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRepoPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var repoPath: String {
        resolvedRepoPath ?? "~"
    }

    private var connection: EnvironmentConnection? {
        environmentStore.connection(for: environmentId)
    }

    private var currentStatus: GitStatusInfo? {
        resolvedRepoPath.flatMap { connection?.gitStatusInfo(for: $0) }
    }

    private var currentStatusError: String? {
        resolvedRepoPath.flatMap { connection?.gitStatusError(for: $0) }
    }

    private var currentCommits: [GitCommit]? {
        resolvedRepoPath.flatMap { connection?.gitLogEntries(for: $0) }
    }

    var body: some View {
        Group {
            if let connection {
                EnvironmentConnectionObserver(connection: connection) { _ in
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
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
        .background(Color.themeBackground(appTheme))
        .sheet(item: $selectedFile) { file in
            GitDiffView(environmentStore: environmentStore, repoPath: repoPath, file: file, environmentId: environmentId)
        }
        .onAppear { loadIfNeeded(); syncStatus(); syncCommits() }
        .onChange(of: resolvedRepoPath) { oldValue, newValue in
            if oldValue != newValue {
                resetAndLoad()
            }
        }
        .onChange(of: environmentId) { oldValue, newValue in
            if oldValue != newValue {
                resetAndLoad()
            }
        }
        .refreshable { loadStatus() }
        .onChange(of: currentStatus) { _, _ in syncStatus() }
        .onChange(of: currentStatusError) { _, _ in syncStatus() }
        .onChange(of: currentCommits) { _, _ in syncCommits() }
    }

    private func loadIfNeeded() {
        if state.isInitialLoad {
            loadStatus()
        } else if let repoPath = resolvedRepoPath {
            pendingRepoPath = repoPath
            connection?.gitStatus.enqueue(repoPath)
        }
    }

    private func resetAndLoad() {
        state.reset()
        loadStatus()
    }

    private func loadStatus() {
        guard let repoPath = resolvedRepoPath else {
            pendingRepoPath = nil
            state.reset()
            return
        }

        connection?.gitStatus.cancelInFlight()
        pendingRepoPath = repoPath
        AppLogger.beginInterval("git.status", key: repoPath)
        connection?.gitStatus.enqueue(repoPath)
    }

    private func syncStatus() {
        if let currentStatus {
            state.applyStatus(currentStatus)
            AppLogger.endInterval("git.status", key: pendingRepoPath ?? repoPath, details: "files=\(currentStatus.files.count)")
            pendingRepoPath = nil
            if !currentStatus.hasChanges, currentCommits == nil {
                connection?.gitLog(path: repoPath)
            }
        } else if let currentStatusError {
            state.applyError()
            AppLogger.cancelInterval("git.status", key: pendingRepoPath ?? repoPath, reason: currentStatusError)
            pendingRepoPath = nil
        }
    }

    private func syncCommits() {
        if let currentCommits {
            state.applyCommits(currentCommits)
        }
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
        .background(Color.themeSecondary(appTheme))
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
                                .listRowBackground(Color.themeBackground(appTheme))
                        }
                    } header: {
                        Text("Recent Commits")
                            .font(.system(size: DS.Text.s, weight: .semibold))
                            .textCase(.uppercase)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground(appTheme))
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
                            .listRowBackground(Color.themeBackground(appTheme))
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
                            .listRowBackground(Color.themeBackground(appTheme))
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
        .background(Color.themeBackground(appTheme))
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
