import Foundation

@main struct RunnerRecordingTests {
    static func main() {
        let runner = RunnerRecordingFixture(
            sessionId: "recording-fixture", hasStartedBefore: false, model: nil,
            effort: nil, permissionMode: nil, queue: DispatchQueue(label: "afto.recording.fixture"))
        var completions = 0
        runner.onFinish = { completions += 1 }
        precondition(!runner.emit(["type": "text", "text": "must not be broadcast"]))
        runner.finish(exitCode: 0)
        precondition(!runner.hasExited && completions == 0)
        runner.accepts = true
        precondition(runner.emit(["type": "error", "message": "storage unavailable"]))
        runner.finish(exitCode: 1)
        precondition(runner.hasExited && completions == 1)
        precondition(runner.attempts.map(\.0) == [1, 1, 1, 2])
        runner.finish(exitCode: 0)
        precondition(completions == 1)
        print(
            "Runner recording: rejected persistence is not emitted, does not advance replay sequence, and cannot publish a successful completion passed"
        )
    }
}
