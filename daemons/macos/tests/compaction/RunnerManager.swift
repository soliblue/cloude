import Foundation

final class RunnerManager {
    static let shared = RunnerManager()
    func reserveCompaction(threadId: String) -> Bool { preconditionFailure("Tests must inject reservations") }
    func releaseCompaction(threadId: String) { preconditionFailure("Tests must inject reservations") }
}
