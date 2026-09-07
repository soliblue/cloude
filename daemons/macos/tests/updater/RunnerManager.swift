import Foundation

final class RunnerManager {
    static let shared = RunnerManager()
    func isIdleForUpdate() -> Bool { false }
}
