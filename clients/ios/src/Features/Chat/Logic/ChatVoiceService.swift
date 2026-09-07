import Foundation

@MainActor enum ChatVoiceService {
    static func start(recorder: ChatAudioRecorder, store: ChatVoiceStore, onError: @escaping (String, String) -> Void) {
        if store.isVisible && !store.isRequestingPermission && !store.isTranscribing && !recorder.isRecording {
            let generation = UUID()
            store.generation = generation
            store.isRequestingPermission = true
            store.task = Task {
                let granted = await recorder.requestPermission()
                if store.isCurrent(generation) {
                    store.isRequestingPermission = false
                    if granted {
                        recorder.start()
                        if !recorder.isRecording { onError("Couldn't start recording", "Check microphone access.") }
                    } else {
                        onError("Microphone access needed", "Enable it in Settings to use voice input.")
                    }
                }
            }
        }
    }

    static func stop(
        recorder: ChatAudioRecorder, store: ChatVoiceStore, session: Session?, onText: @escaping (String) -> Void,
        onError: @escaping (String, String) -> Void
    ) {
        if store.isVisible && recorder.isRecording {
            let data = recorder.stop()
            if let data, !data.isEmpty, let session, let endpoint = session.endpoint {
                let generation = UUID()
                let sessionId = session.id
                let scope = endpoint.cacheId
                store.generation = generation
                store.isTranscribing = true
                store.task = Task {
                    let text = await ChatTranscriptionService.transcribe(
                        endpoint: endpoint, sessionId: sessionId, audio: data)
                    if store.isCurrent(generation) {
                        store.isTranscribing = false
                        if session.endpoint?.cacheId == scope {
                            if let text, !text.isEmpty {
                                onText(text)
                            } else if text == nil {
                                onError(
                                    "Transcription failed",
                                    "Enable speech recognition in Settings or install local Whisper on your remote machine."
                                )
                            } else {
                                onError("No speech detected", "That clip didn't contain any words.")
                            }
                        } else {
                            onError(
                                "Voice input canceled",
                                "The task's connection changed. The recording was not added to your draft.")
                        }
                    }
                }
            } else if data?.isEmpty != false {
                onError("Nothing recorded", "No audio was captured. Try again.")
            } else {
                onError("Not connected", "Connect this task's endpoint to transcribe.")
            }
        }
    }

    static func cancel(recorder: ChatAudioRecorder, store: ChatVoiceStore, onError: (String, String) -> Void) {
        let hadAudio = recorder.isRecording || store.isTranscribing
        store.isVisible = false
        store.generation = UUID()
        store.task?.cancel()
        store.task = nil
        store.isRequestingPermission = false
        store.isTranscribing = false
        if recorder.isRecording { _ = recorder.stop() }
        if hadAudio { onError("Voice input canceled", "The recording was not added to your draft.") }
    }
}
