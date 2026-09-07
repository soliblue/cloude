public final class SFSpeechRecognitionTask {
    public func cancel() {
        SpeechFixture.cancelledTasks += 1
        SpeechFixture.onCancel()
    }
}
