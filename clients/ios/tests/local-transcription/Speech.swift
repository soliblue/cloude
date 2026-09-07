import Foundation

public enum SFSpeechRecognizerAuthorizationStatus: Sendable { case authorized, denied }
public final class SFTranscription: @unchecked Sendable {
    public var formattedString: String
    public init(_ text: String) { formattedString = text }
}
public final class SFSpeechRecognitionResult: @unchecked Sendable {
    public var isFinal = true
    public let bestTranscription: SFTranscription
    public init(_ text: String) { bestTranscription = SFTranscription(text) }
}
@MainActor public final class SFSpeechRecognitionTask {
    public var canceled = false
    public func cancel() { canceled = true }
}
@MainActor public final class SFSpeechURLRecognitionRequest {
    public let url: URL
    public var requiresOnDeviceRecognition = false
    public var shouldReportPartialResults = true
    public var addsPunctuation = false
    public init(url: URL) { self.url = url }
}
@MainActor public final class SFSpeechRecognizer {
    public static var authorizations: [@Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void] = []
    public static var results: [@Sendable (SFSpeechRecognitionResult?, Error?) -> Void] = []
    public static var tasks: [SFSpeechRecognitionTask] = []
    public static var urls: [URL] = []
    public var supportsOnDeviceRecognition = true
    public init?(locale: Locale) {}
    public static func requestAuthorization(
        _ callback: @escaping @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void
    ) { authorizations.append(callback) }
    public func recognitionTask(
        with request: SFSpeechURLRecognitionRequest,
        resultHandler: @escaping @Sendable (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        precondition(request.requiresOnDeviceRecognition && !request.shouldReportPartialResults)
        Self.urls.append(request.url)
        Self.results.append(resultHandler)
        let task = SFSpeechRecognitionTask()
        Self.tasks.append(task)
        return task
    }
}
