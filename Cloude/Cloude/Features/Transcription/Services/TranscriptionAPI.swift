import Combine
import Foundation
import CloudeShared

@MainActor
final class TranscriptionAPI: ObservableObject {
    let environmentId: UUID

    @Published private(set) var isReady = false
    @Published private(set) var isTranscribing = false

    var send: ((ClientMessage) -> Void)?
    var emitEvent: ((ConnectionEvent) -> Void)?

    init(environmentId: UUID) {
        self.environmentId = environmentId
    }

    func transcribe(audioBase64: String) {
        isTranscribing = true
        send?(.transcribe(audioBase64: audioBase64))
    }

    func handleReady(_ ready: Bool) {
        isReady = ready
    }

    func handleResult(_ text: String) {
        isTranscribing = false
        emitEvent?(.transcription(text))
    }

    func handleError(_ errorMessage: String) {
        if errorMessage.lowercased().contains("transcription"), isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    func reset() {
        isReady = false
        isTranscribing = false
    }
}
