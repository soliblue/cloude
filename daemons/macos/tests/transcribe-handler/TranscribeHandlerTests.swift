import Foundation
import Speech

@main struct TranscribeHandlerTests {
    static func main() {
        let head = HTTPRequest.parseHead(Data("POST /sessions/fixture/transcribe HTTP/1.1\r\n\r\n".utf8))!
        let audio = Data("{\"audio\":\"Zml4dHVyZQ==\"}".utf8)
        let success = TranscribeHandler.transcribe(HTTPRequest(head: head, body: audio), params: [:])
        precondition(success.status == 200)
        if case .buffered(let data) = success.body {
            precondition(String(data: data, encoding: .utf8)!.contains("fixture transcript"))
        }
        precondition(SpeechFixture.cancelledTasks == 1 && SpeechFixture.onDeviceRequested)
        precondition(!FileManager.default.fileExists(atPath: SpeechFixture.lastURL!.path))
        precondition(SpeechFixture.lastTask == nil)
        SpeechFixture.finishImmediately = false
        let timeout = TranscribeHandler.transcribe(
            HTTPRequest(head: head, body: audio), params: [:], recognitionTimeout: 0.02)
        precondition(timeout.status == 500 && SpeechFixture.cancelledTasks == 2)
        precondition(!FileManager.default.fileExists(atPath: SpeechFixture.lastURL!.path))
        precondition(SpeechFixture.lastTask == nil)

        SpeechFixture.taskStarted = DispatchSemaphore(value: 0)
        let cancellation = HTTPRequestCancellation()
        DispatchQueue.global().async {
            SpeechFixture.taskStarted.wait()
            cancellation.cancel()
        }
        let began = Date()
        let disconnected = TranscribeHandler.transcribe(
            HTTPRequest(head: head, body: audio, cancellation: cancellation), params: [:])
        precondition(disconnected.status == 500 && SpeechFixture.cancelledTasks == 3)
        precondition(Date().timeIntervalSince(began) < 0.5)
        precondition(!FileManager.default.fileExists(atPath: SpeechFixture.lastURL!.path))
        precondition(SpeechFixture.lastTask == nil)

        SpeechFixture.authorized = false
        let authorizationTimedOut = TranscribeHandler.transcribe(
            HTTPRequest(head: head, body: audio), params: [:], authorizationTimeout: 0.02)
        precondition(authorizationTimedOut.status == 503 && SpeechFixture.cancelledTasks == 3)
        SpeechFixture.authorizationStarted = DispatchSemaphore(value: 0)
        let authCancellation = HTTPRequestCancellation()
        DispatchQueue.global().async {
            SpeechFixture.authorizationStarted.wait()
            authCancellation.cancel()
        }
        let authBegan = Date()
        let cancelledAuthorization = TranscribeHandler.transcribe(
            HTTPRequest(head: head, body: audio, cancellation: authCancellation), params: [:])
        precondition(cancelledAuthorization.status == 503)
        precondition(Date().timeIntervalSince(authBegan) < 0.5)
        SpeechFixture.authorizeImmediately = true
        SpeechFixture.taskStarted = DispatchSemaphore(value: 0)
        let transitionCancellation = HTTPRequestCancellation()
        DispatchQueue.global().async {
            SpeechFixture.taskStarted.wait()
            transitionCancellation.cancel()
        }
        let transitioned = TranscribeHandler.transcribe(
            HTTPRequest(head: head, body: audio, cancellation: transitionCancellation), params: [:])
        precondition(transitioned.status == 500 && SpeechFixture.cancelledTasks == 4)
        precondition(SpeechFixture.lastTask == nil)
        precondition(!FileManager.default.fileExists(atPath: SpeechFixture.lastURL!.path))
        for scenario in ["recognition_cancel", "recognition_timeout", "authorization_cancel", "authorization_timeout"] {
            SpeechFixture.authorized = scenario.hasPrefix("recognition")
            SpeechFixture.authorizeImmediately = false
            SpeechFixture.finishImmediately = false
            SpeechFixture.taskStarted = DispatchSemaphore(value: 0)
            SpeechFixture.authorizationStarted = DispatchSemaphore(value: 0)
            let cleanupStarted = DispatchSemaphore(value: 0)
            let allowCleanup = DispatchSemaphore(value: 0)
            let finished = DispatchSemaphore(value: 0)
            let cancellation = HTTPRequestCancellation()
            SpeechFixture.onCancel = {
                cleanupStarted.signal()
                precondition(allowCleanup.wait(timeout: .now() + 2) == .success)
            }
            DispatchQueue.global().async {
                let response = TranscribeHandler.transcribe(
                    HTTPRequest(head: head, body: audio, cancellation: cancellation), params: [:],
                    authorizationTimeout: 0.3, recognitionTimeout: 0.3)
                precondition(response.status == (scenario.hasPrefix("recognition") ? 500 : 503))
                finished.signal()
            }
            precondition(
                (scenario.hasPrefix("recognition") ? SpeechFixture.taskStarted : SpeechFixture.authorizationStarted)
                    .wait(timeout: .now() + 2) == .success)
            DispatchQueue.concurrentPerform(iterations: 8) { index in
                let busy = TranscribeHandler.transcribe(
                    HTTPRequest(head: head, body: index.isMultiple(of: 2) ? audio : Data([0xFF])), params: [:])
                precondition(busy.status == 429)
                if case .buffered(let data) = busy.body {
                    precondition(String(data: data, encoding: .utf8)!.contains("transcription_busy"))
                }
            }
            if scenario.hasSuffix("cancel") { cancellation.cancel() }
            if scenario.hasPrefix("recognition") {
                precondition(cleanupStarted.wait(timeout: .now() + 2) == .success)
                precondition(
                    TranscribeHandler.transcribe(HTTPRequest(head: head, body: audio), params: [:]).status == 429)
                precondition(
                    TranscribeHandler.transcribe(HTTPRequest(head: head, body: Data([0xFF])), params: [:]).status == 429
                )
                allowCleanup.signal()
            }
            precondition(finished.wait(timeout: .now() + 2) == .success)
            precondition(SpeechFixture.lastTask == nil)
            precondition(!FileManager.default.fileExists(atPath: SpeechFixture.lastURL!.path))
            SpeechFixture.onCancel = {}
            SpeechFixture.authorized = true
            SpeechFixture.finishImmediately = true
            precondition(
                TranscribeHandler.transcribe(HTTPRequest(head: head, body: Data([0xFF])), params: [:]).status == 400)
            precondition(TranscribeHandler.transcribe(HTTPRequest(head: head, body: audio), params: [:]).status == 200)
        }
        print(
            "PASS actual transcription handler result, task cancellation, deadline, disconnect, authorization wait, temporary-file cleanup, concurrent 429 before parsing, cleanup-held gate and later recovery with isolated Speech module"
        )
    }
}
