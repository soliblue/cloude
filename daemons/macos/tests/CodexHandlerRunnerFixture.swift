import Foundation

final class RunnerManager {
    static let shared = RunnerManager()
    var compacting: Set<String> = []
    func isCompacting(threadId: String) -> Bool { compacting.contains(threadId) }
    var active: Set<String> = []
    func isRunning(sessionId: String) -> Bool { active.contains(sessionId.lowercased()) }
}
