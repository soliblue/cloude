//
//  WhisperService.swift
//  Cloude Agent
//

import Foundation
import WhisperKit
import AVFoundation
import Combine

@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()

    @Published var isReady = false
    @Published var isTranscribing = false
    @Published var downloadProgress: Double = 0

    private var whisperKit: WhisperKit?
    private let modelVariant = "base"

    var onReady: (() -> Void)?

    private init() {}

    func initialize() async {
        print("[WhisperService] Starting initialization...")

        let modelFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cloude/WhisperModels")

        do {
            try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)

            print("[WhisperService] Downloading/loading model...")
            let modelPath = try await WhisperKit.download(
                variant: modelVariant,
                downloadBase: modelFolder,
                useBackgroundSession: false
            ) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    print("[WhisperService] Download progress: \(Int(progress.fractionCompleted * 100))%")
                }
            }

            print("[WhisperService] Initializing WhisperKit with model at: \(modelPath)")
            whisperKit = try await WhisperKit(modelFolder: modelPath.path)

            isReady = true
            print("[WhisperService] Ready!")
            onReady?()
        } catch {
            print("[WhisperService] Failed to initialize: \(error)")
        }
    }

    func transcribe(audioBase64: String) async throws -> String {
        guard let audioData = Data(base64Encoded: audioBase64) else {
            throw WhisperError.invalidAudio
        }
        return try await transcribe(audioData: audioData)
    }

    func transcribe(audioData: Data) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw WhisperError.notReady
        }

        isTranscribing = true
        defer { isTranscribing = false }

        print("[WhisperService] Starting transcription, audio size: \(audioData.count) bytes")

        let samples = try audioDataToSamples(audioData)
        print("[WhisperService] Converted to \(samples.count) samples")

        var options = DecodingOptions()
        options.verbose = false

        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)

        print("[WhisperService] Transcription result: \(text)")
        return text
    }

    private func audioDataToSamples(_ data: Data) throws -> [Float] {
        var samples: [Float] = []
        let headerSize = 44

        guard data.count > headerSize else {
            throw WhisperError.invalidAudio
        }

        let audioData = data.dropFirst(headerSize)
        let sampleCount = audioData.count / 2

        samples.reserveCapacity(sampleCount)

        audioData.withUnsafeBytes { buffer in
            let int16Buffer = buffer.bindMemory(to: Int16.self)
            for sample in int16Buffer {
                samples.append(Float(sample) / Float(Int16.max))
            }
        }

        return samples
    }
}

enum WhisperError: Error, LocalizedError {
    case notReady
    case invalidAudio

    var errorDescription: String? {
        switch self {
        case .notReady: return "Whisper model not loaded"
        case .invalidAudio: return "Invalid audio data"
        }
    }
}
