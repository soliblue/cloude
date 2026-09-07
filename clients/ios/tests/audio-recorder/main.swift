import AVFoundation
import Foundation

@main struct RecorderTests {
    @MainActor static func main() async {
        let recorder = ChatAudioRecorder()
        let first = Task { await recorder.requestPermission() }
        for _ in 0..<10000 where AVAudioApplication.callbacks.isEmpty { await Task.yield() }
        first.cancel()
        let canceled = await first.value
        precondition(!canceled)
        let second = Task { await recorder.requestPermission() }
        for _ in 0..<10000 where AVAudioApplication.callbacks.count < 2 { await Task.yield() }
        AVAudioApplication.callbacks[0](true)
        AVAudioApplication.callbacks[1](false)
        let current = await second.value
        precondition(!current, "Stale grant cannot resolve later denied permission")
        recorder.start()
        recorder.start()
        precondition(AVAudioRecorder.starts == 1 && recorder.isRecording)
        _ = recorder.stop()
        precondition(!recorder.isRecording && recorder.level == 0)
        print("PASS actual recorder permission cancellation, stale grant fencing, idempotent start and stop cleanup")
    }
}
