import Foundation
import Observation

@MainActor @Observable final class SessionWorktreeStore {
    var branches: [SessionWorktreeBranch] = []
    var baseRef = ""
    var branch = ""
    var isLoading = false
    var isCreating = false
    var error: String?
    var createdSession: Session?
    var generation = UUID()
    var requestId = UUID()
    var requestConfiguration: [String] = []

    var branchName: String { branch.trimmingCharacters(in: .whitespacesAndNewlines) }
    var branchError: String? {
        if branches.contains(where: { $0.name == branchName }) {
            return "Choose a new branch name. This branch already exists."
        }
        if branchName.contains(where: \.isWhitespace) || branchName.hasPrefix("-") {
            return "Use a branch name without spaces or a leading hyphen."
        }
        return nil
    }
    var canCreate: Bool {
        !isLoading && !isCreating && !branchName.isEmpty && branchError == nil
            && branches.contains { $0.name == baseRef }
    }

    func prepareRequest(path: String) -> UUID {
        let configuration = [path, branchName, baseRef]
        if requestConfiguration != configuration {
            requestId = UUID()
            requestConfiguration = configuration
        }
        return requestId
    }

    func apply(_ page: SessionWorktreeBranches) {
        var seen = Set<String>()
        branches = page.branches.filter { !$0.name.isEmpty && seen.insert($0.name).inserted }
        if let name = page.defaultBranch, !name.isEmpty, !seen.contains(name) {
            branches.append(SessionWorktreeBranch(name: name, current: false))
        }
        if !branches.contains(where: { $0.name == baseRef }) {
            baseRef =
                page.defaultBranch.flatMap { name in branches.first { $0.name == name }?.name }
                ?? branches.first(where: \.current)?.name ?? branches.first?.name ?? ""
        }
    }
}
