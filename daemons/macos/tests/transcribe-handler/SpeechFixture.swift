import Foundation

public enum SpeechFixture {
    public static var authorized = true
    public static var authorizeImmediately = false
    public static weak var lastTask: SFSpeechRecognitionTask?
    public static var finishImmediately = true
    public static var cancelledTasks = 0
    public static var lastURL: URL?
    public static var taskStarted = DispatchSemaphore(value: 0)
    public static var authorizationStarted = DispatchSemaphore(value: 0)
    public static var onDeviceRequested = false
}
