import Foundation
import Combine
import CloudeShared

@MainActor
class GitChangesState: ObservableObject {
    @Published var gitStatus: GitStatusInfo?
    @Published var recentCommits: [GitCommit] = []
    @Published var isInitialLoad = true
    var pendingRepoPath: String?

    func applyStatus(_ status: GitStatusInfo) {
        gitStatus = status
        isInitialLoad = false
    }

    func applyError() {
        gitStatus = nil
        isInitialLoad = false
    }

    func applyCommits(_ commits: [GitCommit]) {
        recentCommits = commits
    }

    func loadIfNeeded(repoPath: String?, git: GitRuntime?) {
        if isInitialLoad {
            loadStatus(repoPath: repoPath, git: git)
        } else if let repoPath {
            pendingRepoPath = repoPath
            git?.requestStatus(repoPath)
        }
    }

    func resetAndLoadStatus(repoPath: String?, git: GitRuntime?) {
        reset()
        loadStatus(repoPath: repoPath, git: git)
    }

    func loadStatus(repoPath: String?, git: GitRuntime?) {
        if let repoPath {
            git?.cancelPendingStatus()
            pendingRepoPath = repoPath
            AppLogger.beginInterval("git.status", key: repoPath)
            git?.requestStatus(repoPath)
        } else {
            pendingRepoPath = nil
            reset()
        }
    }

    func sync(repoPath: String, currentStatus: GitStatusInfo?, currentStatusError: String?, currentCommits: [GitCommit]?, git: GitRuntime?) {
        if let currentStatus {
            applyStatus(currentStatus)
            AppLogger.endInterval("git.status", key: pendingRepoPath ?? repoPath, details: "files=\(currentStatus.files.count)")
            pendingRepoPath = nil
            if !currentStatus.hasChanges, currentCommits == nil {
                git?.log(path: repoPath)
            }
        } else if let currentStatusError {
            applyError()
            AppLogger.cancelInterval("git.status", key: pendingRepoPath ?? repoPath, reason: currentStatusError)
            pendingRepoPath = nil
        }
        if let currentCommits {
            applyCommits(currentCommits)
        }
    }

    func reset() {
        gitStatus = nil
        recentCommits = []
        isInitialLoad = true
        pendingRepoPath = nil
    }
}
