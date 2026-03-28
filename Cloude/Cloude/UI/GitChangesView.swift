import SwiftUI
import CloudeShared

struct GitChangesView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?

    @State private var gitStatus: GitStatusInfo?
    @State private var isLoading = false
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
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = gitStatus {
                statusHeader(status)
                filesList(status.files)
            } else {
                ContentUnavailableView("No Repository", systemImage: "folder.badge.questionmark", description: Text("Not a git repository"))
            }
        }
        .sheet(item: $selectedFile) { file in
            GitDiffView(connection: connection, repoPath: repoPath, file: file, environmentId: environmentId)
        }
        .onAppear { loadStatus() }
        .onChange(of: rootPath) { _, _ in
            loadStatus()
        }
        .onChange(of: connection.connection(for: environmentId)?.isAuthenticated ?? false) { _, isAuthenticated in
            if isAuthenticated && isLoading && gitStatus == nil {
                loadStatus()
            }
        }
        .onChange(of: defaultWorkingDirectory) { _, newValue in
            if rootPath == nil, newValue?.isEmpty == false {
                loadStatus()
            }
        }
        .refreshable { loadStatus() }
        .onReceive(connection.events) { event in
            if case let .gitStatus(path, status, envId) = event, path == repoPath, envId == environmentId {
                gitStatus = status
                isLoading = false
                AppLogger.endInterval("git.status", key: pendingRepoPath ?? path, details: "files=\(status.files.count)")
                pendingRepoPath = nil
            } else if case let .gitStatusError(path, _, envId) = event, path == repoPath, envId == environmentId {
                isLoading = false
                gitStatus = nil
                AppLogger.cancelInterval("git.status", key: pendingRepoPath ?? path, reason: "error")
                pendingRepoPath = nil
            }
        }
    }

    private func statusHeader(_ status: GitStatusInfo) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: DS.Text.m))
                .foregroundColor(.secondary)
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
                            .foregroundColor(.pastelGreen)
                    }
                    if totalDel > 0 {
                        Text("-\(totalDel)")
                            .foregroundColor(.pastelRed)
                    }
                }
                .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                Text("·")
                    .foregroundColor(.secondary)
            }

            if !status.stagedFiles.isEmpty {
                Text("\(status.stagedFiles.count) staged")
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(.pastelGreen)
                Text("·")
                    .foregroundColor(.secondary)
            }
            Text("\(status.unstagedFiles.count) changed")
                .font(.system(size: DS.Text.s, weight: .medium))
                .foregroundColor(status.hasChanges ? .orange : .pastelGreen)
        }
        .font(.system(size: DS.Text.s))
        .foregroundColor(.secondary)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .background(Color.themeSecondary)
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

    private func loadStatus() {
        guard let repoPath = resolvedRepoPath else {
            pendingRepoPath = nil
            gitStatus = nil
            isLoading = connection.connection(for: environmentId)?.isAuthenticated != true
            return
        }

        if let conn = connection.connection(for: environmentId) {
            if conn.gitStatusInFlightPath != nil {
                conn.gitStatusTimeoutTask?.cancel()
                conn.gitStatusInFlightPath = nil
            }
        }
        pendingRepoPath = repoPath
        AppLogger.beginInterval("git.status", key: repoPath)
        isLoading = true
        gitStatus = nil
        connection.gitStatus(path: repoPath, environmentId: environmentId)
    }
}
