import Foundation
import CloudeShared
import KokoroSwift
import MLXUtilsLibrary
import MLX
import AVFoundation
import Combine

@MainActor
class KokoroService: ObservableObject {
    static let shared = KokoroService()

    @Published var isReady = false
    @Published var isSynthesizing = false
    @Published var downloadProgress: Double = 0

    private var engine: KokoroTTS?
    private var voices: [String: MLXArray] = [:]
    private var voiceNames: [String] = []
    private let defaultVoice = "af_heart"
    private let sampleRate: Double = 24000

    private let modelDir: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cloude/KokoroTTS")
    }()

    private let modelFileName = "kokoro-v1_0.safetensors"
    private let voicesFileName = "voices.npz"
    private let modelURL = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/kokoro-v1_0.safetensors"
    private let voicesURL = "https://github.com/mlalma/KokoroTestApp/raw/main/Resources/voices.npz"

    var onReady: (() -> Void)?

    private init() {}

    func initialize() async {
        Log.info("KokoroService: Starting initialization")

        do {
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            let modelPath = modelDir.appendingPathComponent(modelFileName)
            let voicesPath = modelDir.appendingPathComponent(voicesFileName)

            if !FileManager.default.fileExists(atPath: modelPath.path) {
                Log.info("KokoroService: Downloading model (~86MB)...")
                try await downloadFile(from: modelURL, to: modelPath)
            }

            if !FileManager.default.fileExists(atPath: voicesPath.path) {
                Log.info("KokoroService: Downloading voices...")
                try await downloadFile(from: voicesURL, to: voicesPath)
            }

            Log.info("KokoroService: Loading model from \(modelPath.lastPathComponent)")
            engine = KokoroTTS(modelPath: modelPath)

            Log.info("KokoroService: Loading voices from \(voicesPath.lastPathComponent)")
            if let loadedVoices = NpyzReader.read(fileFromPath: voicesPath) {
                voices = loadedVoices
                voiceNames = voices.keys.map { String($0.split(separator: ".")[0]) }.sorted()
                Log.info("KokoroService: Loaded \(voiceNames.count) voices")
            }

            isReady = true
            Log.info("KokoroService: Ready")
            onReady?()
        } catch {
            Log.error("KokoroService: Failed to initialize: \(error)")
        }
    }

    func synthesize(text: String) async throws -> Data {
        guard let engine = engine else { throw KokoroError.notReady }

        let voiceKey = defaultVoice + ".npy"
        guard let voice = voices[voiceKey] else { throw KokoroError.noVoice }

        isSynthesizing = true
        defer { isSynthesizing = false }

        Log.debug("KokoroService: Synthesizing \(text.count) chars")

        let language: KokoroLanguage = defaultVoice.first == "a" ? .enUS : .enGB
        let (audio, _) = try engine.generateAudio(voice: voice, language: language, text: text)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count))!
        buffer.frameLength = buffer.frameCapacity

        audio.withUnsafeBufferPointer { buf in
            let dst = buffer.floatChannelData![0]
            UnsafeMutableRawPointer(dst).copyMemory(
                from: UnsafeRawPointer(buf.baseAddress!),
                byteCount: buf.count * MemoryLayout<Float>.stride
            )
        }

        return pcmBufferToWAV(buffer, sampleRate: sampleRate)
    }

    private func pcmBufferToWAV(_ buffer: AVAudioPCMBuffer, sampleRate: Double) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = UInt32(buffer.frameLength) * UInt32(channels) * UInt32(bytesPerSample)

        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        data.append(contentsOf: "RIFF".utf8)
        withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        withUnsafeBytes(of: UInt32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: channels.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(UInt32(sampleRate) * UInt32(channels) * UInt32(bytesPerSample)).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: (channels * bytesPerSample).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { data.append(contentsOf: $0) }

        data.append(contentsOf: "data".utf8)
        withUnsafeBytes(of: dataSize.littleEndian) { data.append(contentsOf: $0) }

        let floatData = buffer.floatChannelData![0]
        for i in 0..<Int(buffer.frameLength) {
            let clamped = max(-1.0, min(1.0, floatData[i]))
            let sample = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
        }

        return data
    }

    private func downloadFile(from urlString: String, to destination: URL) async throws {
        guard let url = URL(string: urlString) else { throw KokoroError.downloadFailed }

        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw KokoroError.downloadFailed
        }

        try FileManager.default.moveItem(at: tempURL, to: destination)
        downloadProgress = 1.0
    }
}

enum KokoroError: Error, LocalizedError {
    case notReady
    case noVoice
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .notReady: return "Kokoro model not loaded"
        case .noVoice: return "No voice loaded"
        case .downloadFailed: return "Model download failed"
        }
    }
}
