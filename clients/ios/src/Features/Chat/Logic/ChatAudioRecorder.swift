import AVFoundation
import Foundation

@MainActor
@Observable
final class ChatAudioRecorder {
    private(set) var isRecording = false
    var level: CGFloat = 0
    private var permission: CheckedContinuation<Bool, Never>?
    private var permissionGeneration: UUID?
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "afto-recording-\(UUID().uuidString).wav")

    func requestPermission() async -> Bool {
        if let permissionGeneration { finishPermission(false, generation: permissionGeneration) }
        let generation = UUID()
        permissionGeneration = generation
        return await withTaskCancellationHandler {
            if Task.isCancelled { return false }
            return await withCheckedContinuation { continuation in
                permission = continuation
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    Task { @MainActor [weak self] in self?.finishPermission(granted, generation: generation) }
                }
            }
        } onCancel: {
            Task { @MainActor in self.finishPermission(false, generation: generation) }
        }
    }

    private func finishPermission(_ allowed: Bool, generation: UUID) {
        if permissionGeneration == generation {
            permissionGeneration = nil
            let continuation = permission
            permission = nil
            continuation?.resume(returning: allowed)
        }
    }

    func start() {
        if isRecording { return }
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
                Task { @MainActor [weak self] in self?.updateLevel() }
            }
        }
    }

    func stop() -> Data? {
        defer { try? FileManager.default.removeItem(at: url) }
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
