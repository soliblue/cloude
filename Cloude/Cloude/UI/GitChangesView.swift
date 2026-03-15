import SwiftUI
import CloudeShared

struct GitChangesView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?

    @State private var gitStatus: GitStatusInfo?
    @State private var isLoading = false
    @State private var selectedFile: GitFileStatus?

    private var repoPath: String {
        rootPath ?? "~"
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = gitStatus {
                statusHeader(status)
                Divider()
                filesList(status.files)
            } else {
                ContentUnavailableView("No Repository", systemImage: "folder.badge.questionmark", description: Text("Not a git repository"))
            }
        }
        .navigationTitle("Git Changes")
        .sheet(item: $selectedFile) { file in
            GitDiffView(connection: connection, repoPath: repoPath, file: file, environmentId: environmentId)
        }
        .onAppear { loadStatus() }
        .refreshable { loadStatus() }
        .onReceive(connection.events) { event in
            if case let .gitStatus(path, status, envId) = event, path == repoPath, envId == environmentId {
                gitStatus = status
                isLoading = false
            }
        }
    }

    private func statusHeader(_ status: GitStatusInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(status.branch)
                .font(.system(size: 14, weight: .semibold))

            if status.ahead > 0 {
                Label("\(status.ahead)", systemImage: "arrow.up")
            }
            if status.behind > 0 {
                Label("\(status.behind)", systemImage: "arrow.down")
            }

            Spacer()
            if !status.stagedFiles.isEmpty {
                Text("\(status.stagedFiles.count) staged")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                Text("·")
                    .foregroundColor(.secondary)
            }
            Text("\(status.unstagedFiles.count) changed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(status.hasChanges ? .orange : .green)
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                    }
                } header: {
                    Text("Staged")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
            if !unstaged.isEmpty {
                Section {
                    ForEach(unstaged) { file in
                        GitFileRow(file: file) { selectedFile = file }
                    }
                } header: {
                    Text("Changes")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
    }

    private func loadStatus() {
        if let conn = connection.connection(for: environmentId) {
            if conn.gitStatusInFlightPath != nil {
                conn.gitStatusTimeoutTask?.cancel()
                conn.gitStatusInFlightPath = nil
            }
        }
        isLoading = true
        gitStatus = nil
        connection.gitStatus(path: repoPath, environmentId: environmentId)
    }
}
