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
            Text("\(status.files.count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(status.hasChanges ? .orange : .green)
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.oceanSecondary)
    }

    private func filesList(_ files: [GitFileStatus]) -> some View {
        List(files) { file in
            GitFileRow(file: file) {
                selectedFile = file
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
