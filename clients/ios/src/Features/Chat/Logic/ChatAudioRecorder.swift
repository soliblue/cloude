import AVFoundation
import Foundation

@MainActor
@Observable
final class ChatAudioRecorder {
    private(set) var isRecording = false
    var level: CGFloat = 0
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "cloude-recording.wav")

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        if recorder?.record() == true {
            isRecording = true
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateLevel() }
            }
        }
    }

    func stop() -> Data? {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false)
        return try? Data(contentsOf: url)
    }

    private func updateLevel() {
        recorder?.updateMeters()
        let power = recorder?.averagePower(forChannel: 0) ?? -60
        level = max(0, min(1, CGFloat(power + 60) / 60))
    }
}
