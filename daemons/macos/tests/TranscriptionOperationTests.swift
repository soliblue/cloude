import Foundation

@main struct TranscriptionOperationTests {
    static func main() {
        let success = TranscriptionOperation<String>()
        var cancellationCount = 0
        success.setCancellation { cancellationCount += 1 }
        success.finish("first")
        success.finish("late")
        precondition(success.wait(timeout: 1) == "first")
        precondition(cancellationCount == 1)
        _ = success.wait(timeout: 1)
        precondition(cancellationCount == 1)

        let timedOut = TranscriptionOperation<String>()
        timedOut.setCancellation { cancellationCount += 1 }
        let started = Date()
        precondition(timedOut.wait(timeout: 0.02) == nil)
        precondition(Date().timeIntervalSince(started) < 0.5)
        precondition(cancellationCount == 2)
        timedOut.finish("too late")
        precondition(timedOut.wait(timeout: 1) == nil)

        let disconnected = TranscriptionOperation<String>()
        let request = HTTPRequestCancellation()
        request.observe { disconnected.finish(nil) }
        disconnected.setCancellation { cancellationCount += 1 }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { request.cancel() }
        let disconnectStarted = Date()
        precondition(disconnected.wait(timeout: 55) == nil)
        precondition(Date().timeIntervalSince(disconnectStarted) < 0.5)
        precondition(cancellationCount == 3)
        request.stopObserving()

        let early = TranscriptionOperation<String>()
        let alreadyCancelled = HTTPRequestCancellation()
        alreadyCancelled.cancel()
        alreadyCancelled.observe { early.finish(nil) }
        early.setCancellation { cancellationCount += 1 }
        precondition(early.wait(timeout: 55) == nil)
        precondition(cancellationCount == 4)
        print(
            "PASS transcription final-result fencing, timeout cancellation, disconnect cancellation and early cancellation"
        )
    }
}
