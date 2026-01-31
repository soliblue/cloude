import SwiftUI
import CloudeShared

extension SplitChatView {
    func setupGitStatusHandler() {
        connection.onGitStatus = { status in
            if let projectId = pendingGitChecks.first {
                pendingGitChecks.removeFirst()
                if !status.branch.isEmpty {
                    gitBranches[projectId] = status.branch
                }
                checkNextGitProject()
            }
        }
    }

    func checkGitForAllProjects() {
        pendingGitChecks = projectStore.projects
            .filter { !$0.rootDirectory.isEmpty && gitBranches[$0.id] == nil }
            .map { $0.id }
        checkNextGitProject()
    }

    func checkNextGitProject() {
        guard let projectId = pendingGitChecks.first,
              let project = projectStore.projects.first(where: { $0.id == projectId }) else { return }
        connection.gitStatus(path: project.rootDirectory)
    }
}
