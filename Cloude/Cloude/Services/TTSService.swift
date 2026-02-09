import AVFoundation
import Combine
import SwiftUI
import KokoroSwift
import MLX
import MLXUtilsLibrary

@MainActor
final class TTSService: ObservableObject {
    static let shared = TTSService()

    @Published var isPlaying = false
    @Published var playingMessageId: String?
    @Published var isModelDownloaded = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0

    private var standardSynthesizer = AVSpeechSynthesizer()
    private nonisolated(unsafe) var kokoroEngine: KokoroTTS?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private nonisolated(unsafe) var voices: [String: MLXArray] = [:]

    private let modelFileName = "kokoro-v1_0.safetensors"
    private let voicesFileName = "voices-v1.0.bin"
    private let modelURLString = "https://huggingface.co/prince-canuma/Kokoro-82M/resolve/main/kokoro-v1_0.safetensors"
    private let voicesURLString = "https://huggingface.co/prince-canuma/Kokoro-82M/resolve/main/voices-v1.0.bin"

    private init() {
        checkModelExists()
    }

    private var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KokoroTTS")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var modelPath: URL { modelsDirectory.appendingPathComponent(modelFileName) }
    private var voicesPath: URL { modelsDirectory.appendingPathComponent(voicesFileName) }

    func checkModelExists() {
        isModelDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
            && FileManager.default.fileExists(atPath: voicesPath.path)
    }

    func speak(_ text: String, messageId: String, mode: TTSMode) {
        if isPlaying && playingMessageId == messageId {
            stop()
            return
        }

        stop()

        let stripped = stripMarkdown(text)
        playingMessageId = messageId
        isPlaying = true

        switch mode {
        case .off: return
        case .standard: speakStandard(stripped)
        case .natural: speakNatural(stripped)
        }
    }

    func stop() {
        standardSynthesizer.stopSpeaking(at: .immediate)
        playerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
        playingMessageId = nil
    }

    private func speakStandard(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        standardSynthesizer = AVSpeechSynthesizer()
        standardSynthesizer.speak(utterance)

        Task {
            while standardSynthesizer.isSpeaking {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            isPlaying = false
            playingMessageId = nil
        }
    }

    private func speakNatural(_ text: String) {
        guard isModelDownloaded else {
            speakStandard(text)
            return
        }

        let path = modelPath
        let vPath = voicesPath

        Task.detached {
            do {
                let engine: KokoroTTS
                let voice: MLXArray

                if let existing = self.kokoroEngine, let v = self.voices.values.first {
                    engine = existing
                    voice = v
                } else {
                    engine = KokoroTTS(modelPath: path)
                    self.kokoroEngine = engine

                    if let loadedVoices = NpyzReader.read(fileFromPath: vPath) {
                        self.voices = loadedVoices
                    }

                    guard let v = self.voices.values.first else {
                        await MainActor.run {
                            self.isPlaying = false
                            self.playingMessageId = nil
                        }
                        return
                    }
                    voice = v
                }

                let (samples, _) = try engine.generateAudio(voice: voice, language: .enUS, text: text)

                await MainActor.run {
                    self.playAudioSamples(samples, sampleRate: 24000)
                }
            } catch {
                await MainActor.run {
                    self.isPlaying = false
                    self.playingMessageId = nil
                }
            }
        }
    }

    private func playAudioSamples(_ samples: [Float], sampleRate: Double) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { ptr in
                channelData[0].update(from: ptr.baseAddress!, count: samples.count)
            }
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()

        player.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.playingMessageId = nil
                self?.audioEngine?.stop()
            }
        }
        player.play()

        self.audioEngine = engine
        self.playerNode = player
    }

    func downloadModel() async {
        isDownloading = true
        downloadProgress = 0

        do {
            try await downloadFile(from: modelURLString, to: modelPath, progressWeight: 0.9)
            try await downloadFile(from: voicesURLString, to: voicesPath, progressWeight: 0.1)
            isDownloading = false
            downloadProgress = 1.0
            checkModelExists()
        } catch {
            isDownloading = false
            downloadProgress = 0
        }
    }

    private func downloadFile(from urlString: String, to destination: URL, progressWeight: Double) async throws {
        guard let url = URL(string: urlString) else { return }
        let baseProgress = downloadProgress

        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let totalBytes = response.expectedContentLength
        var downloadedBytes: Int64 = 0
        var data = Data()
        if totalBytes > 0 { data.reserveCapacity(Int(totalBytes)) }

        for try await byte in asyncBytes {
            data.append(byte)
            downloadedBytes += 1
            if downloadedBytes % 100_000 == 0 && totalBytes > 0 {
                downloadProgress = baseProgress + (Double(downloadedBytes) / Double(totalBytes)) * progressWeight
            }
        }

        try data.write(to: destination)
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "^[\\s]*[-*+]\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?m)^>\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\|[^\\n]+\\|", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "---+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
