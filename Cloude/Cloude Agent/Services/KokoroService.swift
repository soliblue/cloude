import Foundation
import CloudeShared
import KokoroSwift
import MLXUtilsLibrary
import MLX
import AVFoundation
import Combine
import NaturalLanguage

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
    private let interChunkSilenceSamples = 2400 // 100ms @ 24kHz

    private let modelDir: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cloude/KokoroTTS")
    }()

    private let modelFileName = "kokoro-v1_0.safetensors"
    private let voicesFileName = "voices.npz"
    private let modelURL = "https://github.com/mlalma/KokoroTestApp/raw/main/Resources/kokoro-v1_0.safetensors"
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

            Log.info("KokoroService: Loading model...")
            suppressStderr {
                engine = KokoroTTS(modelPath: modelPath)
            }

            Log.info("KokoroService: Loading voices...")
            suppressStderr {
                if let loadedVoices = NpyzReader.read(fileFromPath: voicesPath) {
                    voices = loadedVoices
                    voiceNames = voices.keys.map { String($0.split(separator: ".")[0]) }.sorted()
                }
            }
            Log.info("KokoroService: Loaded \(voiceNames.count) voices")

            isReady = true
            Log.info("KokoroService: Ready")
            onReady?()
        } catch {
            Log.error("KokoroService: Failed to initialize: \(error)")
        }
    }

    func synthesize(text: String, voice voiceName: String? = nil) async throws -> Data {
        guard let engine = engine else { throw KokoroError.notReady }

        let selectedVoice = voiceName ?? defaultVoice
        let voiceKey = selectedVoice + ".npy"
        guard let voice = voices[voiceKey] else { throw KokoroError.noVoice }

        isSynthesizing = true
        defer { isSynthesizing = false }

        Log.debug("KokoroService: Synthesizing \(text.count) chars with voice \(selectedVoice)")

        let language: Language = selectedVoice.first == "a" ? .enUS : .enGB
        let chunks = splitTextForSynthesis(text)
        Log.debug("KokoroService: Split into \(chunks.count) chunk(s)")
        var audio: [Float] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkAudio = try generateAudioWithFallback(
                engine: engine,
                voice: voice,
                language: language,
                text: chunk,
                depth: 0
            )
            audio.append(contentsOf: chunkAudio)
            if index < chunks.count - 1 {
                audio.append(contentsOf: repeatElement(Float(0), count: interChunkSilenceSamples))
            }
        }

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

    private func generateAudioWithFallback(
        engine: KokoroTTS,
        voice: MLXArray,
        language: Language,
        text: String,
        depth: Int
    ) throws -> [Float] {
        do {
            var audio: [Float] = []
            try suppressStderr {
                let (result, _) = try engine.generateAudio(voice: voice, language: language, text: text)
                audio = result
            }
            return audio
        } catch let err as KokoroTTS.KokoroTTSError {
            guard err == .tooManyTokens, depth < 6 else { throw err }
            let pieces = splitInHalfAtBoundary(text)
            guard pieces.count == 2 else { throw err }
            let left = try generateAudioWithFallback(engine: engine, voice: voice, language: language, text: pieces[0], depth: depth + 1)
            let right = try generateAudioWithFallback(engine: engine, voice: voice, language: language, text: pieces[1], depth: depth + 1)
            return left + Array(repeatElement(Float(0), count: interChunkSilenceSamples / 2)) + right
        } catch {
            throw error
        }
    }

    private func splitTextForSynthesis(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let maxChunkChars = 260
        let hardMaxChars = 380
        let sentences = splitSentences(normalized)

        var chunks: [String] = []
        var current = ""

        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : current + " " + sentence
            if candidate.count <= maxChunkChars {
                current = candidate
                continue
            }

            if !current.isEmpty {
                chunks.append(current)
                current = ""
            }

            if sentence.count <= hardMaxChars {
                current = sentence
                continue
            }

            // Extra-long sentence: split by words to stay under hard limit.
            chunks.append(contentsOf: splitByWords(sentence, maxChars: hardMaxChars))
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.isEmpty ? [normalized] : chunks
    }

    private func splitSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                result.append(sentence)
            }
            return true
        }
        return result.isEmpty ? [text] : result
    }

    private func splitByWords(_ text: String, maxChars: Int) -> [String] {
        let words = text.split(separator: " ")
        var result: [String] = []
        var current = ""

        for word in words {
            let wordStr = String(word)
            let candidate = current.isEmpty ? wordStr : current + " " + wordStr
            if candidate.count <= maxChars {
                current = candidate
            } else {
                if !current.isEmpty {
                    result.append(current)
                }
                if wordStr.count > maxChars {
                    result.append(contentsOf: splitHard(wordStr, maxChars: maxChars))
                    current = ""
                } else {
                    current = wordStr
                }
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private func splitHard(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start..<end]))
            start = end
        }
        return result
    }

    private func splitInHalfAtBoundary(_ text: String) -> [String] {
        guard text.count > 1 else { return [text] }
        let mid = text.index(text.startIndex, offsetBy: text.count / 2)
        if let split = text[..<mid].lastIndex(where: { $0 == " " || $0 == "," || $0 == "." || $0 == ";" || $0 == ":" || $0 == "!" || $0 == "?" }) {
            let left = String(text[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(text[text.index(after: split)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty && !right.isEmpty {
                return [left, right]
            }
        }

        let left = String(text[..<mid]).trimmingCharacters(in: .whitespacesAndNewlines)
        let right = String(text[mid...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !left.isEmpty && !right.isEmpty {
            return [left, right]
        }
        return [text]
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

    private func downloadFile(from urlString: String, to destination: URL, maxRetries: Int = 3) async throws {
        guard let url = URL(string: urlString) else { throw KokoroError.downloadFailed }

        for attempt in 1...maxRetries {
            do {
                let (tempURL, response) = try await URLSession.shared.download(from: url)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw KokoroError.downloadFailed
                }

                try FileManager.default.moveItem(at: tempURL, to: destination)
                downloadProgress = 1.0
                return
            } catch {
                if attempt == maxRetries { throw error }
                Log.info("KokoroService: Download attempt \(attempt)/\(maxRetries) failed, retrying in 2s...")
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}

@discardableResult
private func suppressStderr<T>(_ body: () throws -> T) rethrows -> T {
    let saved = dup(STDERR_FILENO)
    let devNull = open("/dev/null", O_WRONLY)
    dup2(devNull, STDERR_FILENO)
    close(devNull)
    defer {
        dup2(saved, STDERR_FILENO)
        close(saved)
    }
    return try body()
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
