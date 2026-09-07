import Foundation

public final class SFSpeechRecognizer {
    public let isAvailable = true
    public let supportsOnDeviceRecognition = true
    public init?(locale: Locale = Locale(identifier: "en-US")) {}
    public static func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SpeechFixture.authorized ? .authorized : .notDetermined
    }
    public static func requestAuthorization(_ callback: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SpeechFixture.authorizationStarted.signal()
        if SpeechFixture.authorizeImmediately {
            SpeechFixture.authorized = true
            callback(.authorized)
        }
    }
    public func recognitionTask(
        with request: SFSpeechURLRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        SpeechFixture.onDeviceRequested = request.requiresOnDeviceRecognition
        SpeechFixture.taskStarted.signal()
        if SpeechFixture.finishImmediately { resultHandler(SFSpeechRecognitionResult(), nil) }
        let task = SFSpeechRecognitionTask()
        SpeechFixture.lastTask = task
        return task
    }
}
