import SwiftUI
import CloudeShared

struct GitChangesView: View {
    let environmentStore: EnvironmentStore
    var rootPath: String?
    var environmentId: UUID?
    @ObservedObject var state: GitChangesState
    @Environment(\.appTheme) var appTheme

    @State var selectedFile: GitFileStatus?

    private var defaultWorkingDirectory: String? {
        connection?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRepoPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var repoPath: String {
        resolvedRepoPath ?? "~"
    }

    private var connection: Connection? {
        environmentStore.connectionStore.connection(for: environmentId)
    }

    private var gitRuntime: GitAPI? {
        connection?.git
    }

    private var currentStatus: GitStatusInfo? {
        resolvedRepoPath.flatMap { gitRuntime?.statusInfo(for: $0) }
    }

    private var currentStatusError: String? {
        resolvedRepoPath.flatMap { gitRuntime?.statusError(for: $0) }
    }

    private var currentCommits: [GitCommit]? {
        resolvedRepoPath.flatMap { gitRuntime?.logEntries(for: $0) }
    }

    var body: some View {
        Group {
            if let connection {
                ConnectionObserver(connection: connection) { _ in
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
        .onAppear {
            state.loadIfNeeded(repoPath: resolvedRepoPath, git: gitRuntime)
            state.sync(repoPath: repoPath, currentStatus: currentStatus, currentStatusError: currentStatusError, currentCommits: currentCommits, git: gitRuntime)
        }
        .onChange(of: resolvedRepoPath) { oldValue, newValue in
            if oldValue != newValue {
                state.resetAndLoadStatus(repoPath: newValue, git: gitRuntime)
            }
        }
        .onChange(of: environmentId) { oldValue, newValue in
            if oldValue != newValue {
                state.resetAndLoadStatus(repoPath: resolvedRepoPath, git: gitRuntime)
            }
        }
        .refreshable {
            state.loadStatus(repoPath: resolvedRepoPath, git: gitRuntime)
        }
        .onChange(of: currentStatus) { _, _ in
            state.sync(repoPath: repoPath, currentStatus: currentStatus, currentStatusError: currentStatusError, currentCommits: currentCommits, git: gitRuntime)
        }
        .onChange(of: currentStatusError) { _, _ in
            state.sync(repoPath: repoPath, currentStatus: currentStatus, currentStatusError: currentStatusError, currentCommits: currentCommits, git: gitRuntime)
        }
        .onChange(of: currentCommits) { _, _ in
            state.sync(repoPath: repoPath, currentStatus: currentStatus, currentStatusError: currentStatusError, currentCommits: currentCommits, git: gitRuntime)
        }
    }
}
