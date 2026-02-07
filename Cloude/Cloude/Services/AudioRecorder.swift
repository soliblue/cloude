import AVFoundation
import CloudeShared
import Combine
import Foundation

extension Notification.Name {
    static let pendingAudioCleared = Notification.Name("pendingAudioCleared")
    static let transcriptionFailed = Notification.Name("transcriptionFailed")
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var audioLevel: Float = 0
    @Published var hasPendingAudio = false

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?

    static let pendingAudioURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending_audio.wav")
    }()

    static let pendingAudioCleared = NotificationCenter.default.publisher(for: .pendingAudioCleared)
    static let transcriptionFailed = NotificationCenter.default.publisher(for: .transcriptionFailed)

    static func clearPendingAudioFile() {
        try? FileManager.default.removeItem(at: pendingAudioURL)
        NotificationCenter.default.post(name: .pendingAudioCleared, object: nil)
    }

    static func markTranscriptionFailed() {
        NotificationCenter.default.post(name: .transcriptionFailed, object: nil)
    }

    init() {
        hasPendingAudio = FileManager.default.fileExists(atPath: Self.pendingAudioURL.path)
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: Self.pendingAudioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            startMetering()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                let normalized = max(0, min(1, (db + 60) / 60))
                self.audioLevel = normalized
            }
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    func stopRecording() -> Data? {
        stopMetering()
        audioRecorder?.stop()
        isRecording = false

        do {
            let data = try Data(contentsOf: Self.pendingAudioURL)
            return data
        } catch {
            print("Failed to read recording: \(error)")
            return nil
        }
    }

    func pendingAudioData() -> Data? {
        guard hasPendingAudio else { return nil }
        return try? Data(contentsOf: Self.pendingAudioURL)
    }

    func clearPendingAudio() {
        try? FileManager.default.removeItem(at: Self.pendingAudioURL)
        hasPendingAudio = false
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
}
