import Foundation

final class RunnerRecordingFixture: Runner {
    var accepts = false
    var attempts: [(Int, Data)] = []
    override func record(_ data: Data, seq: Int) -> Bool {
        attempts.append((seq, data))
        return accepts
    }
}
