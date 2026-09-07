import Foundation

final class RunnerManager {
    static let shared = RunnerManager()
    var active: Set<String> = []
    func isRunning(sessionId: String) -> Bool { active.contains(sessionId.lowercased()) }
}
