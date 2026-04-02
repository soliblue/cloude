import Foundation
import Combine
import CloudeShared

@MainActor
class GitChangesState: ObservableObject {
    @Published var gitStatus: GitStatusInfo?
    @Published var recentCommits: [GitCommit] = []
    @Published var isLoading = false
    @Published var isInitialLoad = true

    func applyStatus(_ status: GitStatusInfo) {
        gitStatus = status
        isLoading = false
        isInitialLoad = false
    }

    func applyError() {
        gitStatus = nil
        isLoading = false
        isInitialLoad = false
    }

    func beginLoading() {
        isLoading = true
    }

    func applyCommits(_ commits: [GitCommit]) {
        recentCommits = commits
    }

    func reset() {
        gitStatus = nil
        recentCommits = []
        isLoading = false
        isInitialLoad = true
    }
}
