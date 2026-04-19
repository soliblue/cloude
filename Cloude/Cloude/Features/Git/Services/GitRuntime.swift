import Foundation
import Combine
import CloudeShared

@MainActor
final class GitRuntime: ObservableObject {
    let environmentId: UUID

    @Published private(set) var statuses: [String: GitStatusInfo] = [:]
    @Published private(set) var statusErrors: [String: String] = [:]
    @Published private(set) var logs: [String: [GitCommit]] = [:]
    @Published private(set) var logErrors: [String: String] = [:]
    @Published private(set) var diffs: [GitDiffCacheKey: String] = [:]
    @Published private(set) var diffErrors: [GitDiffCacheKey: String] = [:]

    var send: ((ClientMessage) -> Void)?
    var canSend: () -> Bool = { true } {
        didSet {
            statusService.canSend = canSend
        }
    }
    let statusService = GitStatusService()
    var pendingLogPaths: Set<String> = []
    var activeDiffRequest: GitDiffCacheKey?
    var queuedDiffRequests: [GitDiffCacheKey] = []

    init(environmentId: UUID) {
        self.environmentId = environmentId
        statusService.send = { [weak self] path in
            self?.sendStatus(path: path)
        }
    }

    func requestStatus(_ path: String) {
        statusService.enqueue(path)
    }

    func cancelPendingStatus() {
        statusService.cancelInFlight()
    }

    func sendNextStatusIfReady() {
        statusService.sendNextIfReady()
    }

    func log(path: String, count: Int = 10) {
        pendingLogPaths.insert(path)
        logErrors.removeValue(forKey: path)
        AppLogger.connectionInfo("git log request envId=\(environmentId.uuidString) path=\(path) count=\(count)")
        send?(.gitLog(path: path, count: count))
    }

    func diff(path: String, file: String? = nil, staged: Bool = false) {
        let key = GitDiffCacheKey(repoPath: path, filePath: file, staged: staged)
        diffErrors.removeValue(forKey: key)
        if activeDiffRequest == key || queuedDiffRequests.contains(key) {
            return
        }
        queuedDiffRequests.append(key)
        sendNextDiffIfReady()
    }

    func handleStatusResult(_ status: GitStatusInfo) {
        if let path = statusService.completeInFlight() {
            statusErrors.removeValue(forKey: path)
            statuses[path] = status
            AppLogger.connectionInfo("git status response envId=\(environmentId.uuidString) path=\(path) branch=\(status.branch) files=\(status.files.count)")
        }
    }

    func handleLogResult(path: String, commits: [GitCommit]) {
        pendingLogPaths.remove(path)
        logErrors.removeValue(forKey: path)
        logs[path] = commits
        AppLogger.connectionInfo("git log response envId=\(environmentId.uuidString) path=\(path) commits=\(commits.count)")
    }

    func handleDiffResult(path: String, diff: String) {
        if let key = activeDiffRequest, key.repoPath == path {
            diffErrors.removeValue(forKey: key)
            diffs[key] = diff
            activeDiffRequest = nil
            AppLogger.connectionInfo("git diff response envId=\(environmentId.uuidString) repoPath=\(path) file=\(key.filePath ?? "-") staged=\(key.staged) chars=\(diff.count)")
            sendNextDiffIfReady()
        }
    }

    func reset() {
        statuses = [:]
        statusErrors = [:]
        logs = [:]
        logErrors = [:]
        diffs = [:]
        diffErrors = [:]
        pendingLogPaths = []
        activeDiffRequest = nil
        queuedDiffRequests = []
        statusService.reset()
    }

    func failPendingOperations(_ message: String) {
        if let path = statusService.completeInFlight() {
            statusErrors[path] = message
        }
        for path in pendingLogPaths {
            logErrors[path] = message
        }
        if let activeDiffRequest {
            diffErrors[activeDiffRequest] = message
        }
        for request in queuedDiffRequests {
            diffErrors[request] = message
        }
        pendingLogPaths = []
        activeDiffRequest = nil
        queuedDiffRequests = []
    }

    private func sendStatus(path: String) {
        AppLogger.connectionInfo("git status request envId=\(environmentId.uuidString) path=\(path)")
        send?(.gitStatus(path: path))
    }

    private func sendNextDiffIfReady() {
        guard activeDiffRequest == nil, let nextRequest = queuedDiffRequests.first else {
            return
        }
        queuedDiffRequests.removeFirst()
        activeDiffRequest = nextRequest
        AppLogger.connectionInfo("git diff request envId=\(environmentId.uuidString) repoPath=\(nextRequest.repoPath) file=\(nextRequest.filePath ?? "-") staged=\(nextRequest.staged)")
        send?(.gitDiff(path: nextRequest.repoPath, file: nextRequest.filePath, staged: nextRequest.staged))
    }
}
