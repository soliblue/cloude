import Foundation
import Combine
import CloudeShared

@MainActor
class GitChangesState: ObservableObject {
    @Published var gitStatus: GitStatusInfo?
    @Published var recentCommits: [GitCommit] = []
    @Published var isInitialLoad = true

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

    func reset() {
        gitStatus = nil
        recentCommits = []
        isInitialLoad = true
    }
}
