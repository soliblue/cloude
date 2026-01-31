//
//  AudioRecorder.swift
//  Cloude
//

import AVFoundation
import Combine
import Foundation

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording.wav")
        recordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
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

        guard let url = recordingURL else { return nil }

        do {
            let data = try Data(contentsOf: url)
            try FileManager.default.removeItem(at: url)
            return data
        } catch {
            print("Failed to read recording: \(error)")
            return nil
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
}
