import Foundation

@main struct VoiceTests {
    @MainActor static func main() async {
        let recorder = ChatAudioRecorder()
        let store = ChatVoiceStore()
        let session = Session(endpoint: Endpoint())
        var text = "Newer draft"
        var errors: [String] = []
        let onError: (String, String) -> Void = { title, _ in errors.append(title) }
        store.isVisible = true
        ChatVoiceService.start(recorder: recorder, store: store, onError: onError)
        let pending = store.task!
        for _ in 0..<10000 where recorder.permission == nil { await Task.yield() }
        ChatVoiceService.cancel(recorder: recorder, store: store, onError: onError)
        store.isVisible = true
        recorder.permission?.resume(returning: true)
        recorder.permission = nil
        await pending.value
        precondition(recorder.starts == 0, "Late grant after disappear/reopen never starts recording")
        ChatVoiceService.start(recorder: recorder, store: store, onError: onError)
        let allowed = store.task!
        for _ in 0..<10000 where recorder.permission == nil { await Task.yield() }
        recorder.permission?.resume(returning: true)
        recorder.permission = nil
        await allowed.value
        precondition(recorder.isRecording)
        ChatVoiceService.stop(
            recorder: recorder, store: store, session: session, onText: { text += $0 }, onError: onError)
        let transcription = store.task!
        for _ in 0..<10000 where ChatTranscriptionService.continuation == nil { await Task.yield() }
        ChatVoiceService.cancel(recorder: recorder, store: store, onError: onError)
        store.isVisible = true
        ChatTranscriptionService.continuation?.resume(returning: "late old speech")
        ChatTranscriptionService.continuation = nil
        await transcription.value
        precondition(text == "Newer draft" && errors.last == "Voice input canceled")
        recorder.isRecording = true
        ChatVoiceService.stop(
            recorder: recorder, store: store, session: session, onText: { text += $0 }, onError: onError)
        let changed = store.task!
        for _ in 0..<10000 where ChatTranscriptionService.continuation == nil { await Task.yield() }
        session.endpoint?.cacheId = UUID()
        ChatTranscriptionService.continuation?.resume(returning: "old host speech")
        ChatTranscriptionService.continuation = nil
        await changed.value
        precondition(text == "Newer draft" && !store.isTranscribing)
        recorder.isRecording = true
        ChatVoiceService.cancel(recorder: recorder, store: store, onError: onError)
        precondition(!recorder.isRecording && recorder.stops == 3)
        print(
            "PASS voice lifecycle: late microphone grant blocked, pending recognition canceled, reopened draft preserved, changed host callback ignored, recording stopped on disappearance"
        )
    }
}
