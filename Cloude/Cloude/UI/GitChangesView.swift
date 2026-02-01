import SwiftUI
import CloudeShared

struct GitChangesView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?

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
            GitDiffView(connection: connection, repoPath: repoPath, file: file)
        }
        .onAppear { loadStatus() }
        .refreshable { loadStatus() }
    }

    private func statusHeader(_ status: GitStatusInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(status.branch)
                        .font(.headline)
                }

                HStack(spacing: 12) {
                    if status.ahead > 0 {
                        Label("\(status.ahead) ahead", systemImage: "arrow.up")
                    }
                    if status.behind > 0 {
                        Label("\(status.behind) behind", systemImage: "arrow.down")
                    }
                    if status.ahead == 0 && status.behind == 0 {
                        Text("Up to date")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(status.files.count)")
                .font(.title2.bold())
                .foregroundColor(status.hasChanges ? .orange : .green)
        }
        .padding()
        .background(Color.oceanSecondary)
    }

    private func filesList(_ files: [GitFileStatus]) -> some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView("No Changes", systemImage: "checkmark.circle", description: Text("Working tree clean"))
            } else {
                List(files) { file in
                    GitFileRow(file: file) {
                        selectedFile = file
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func loadStatus() {
        isLoading = true
        gitStatus = nil

        connection.onGitStatus = { status in
            gitStatus = status
            isLoading = false
        }

        connection.gitStatus(path: repoPath)
    }
}
