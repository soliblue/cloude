import Foundation

public final class SFSpeechURLRecognitionRequest {
    public var shouldReportPartialResults = true
    public var requiresOnDeviceRecognition = false
    public init(url: URL) { SpeechFixture.lastURL = url }
}
