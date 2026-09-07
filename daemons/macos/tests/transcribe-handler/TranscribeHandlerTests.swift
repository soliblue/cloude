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
        print(
            "PASS actual transcription handler result, task cancellation, deadline, disconnect, authorization wait and temporary-file cleanup with isolated Speech module"
        )
    }
}
