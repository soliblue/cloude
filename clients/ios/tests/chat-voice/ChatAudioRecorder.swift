import Foundation

@MainActor final class ChatAudioRecorder {
    var permission: CheckedContinuation<Bool, Never>?
    var isRecording = false
    var starts = 0
    var stops = 0
    func requestPermission() async -> Bool { await withCheckedContinuation { permission = $0 } }
    func start() {
        starts += 1
        isRecording = true
    }
    func stop() -> Data? {
        stops += 1
        isRecording = false
        return Data([1])
    }
}
