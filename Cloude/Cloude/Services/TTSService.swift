import AVFoundation
import Combine
import SwiftUI

@MainActor
final class TTSService: ObservableObject {
    static let shared = TTSService()

    @Published var isPlaying = false
    @Published var isSynthesizing = false
    @Published var playingMessageId: String?

    private var standardSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var pendingMessageId: String?

    var onSynthesizeRequest: ((String, String, String?) -> Void)?

    private init() {}

    func speak(_ text: String, messageId: String, mode: TTSMode, voice: String? = nil) {
        if (isPlaying || isSynthesizing) && playingMessageId == messageId {
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
        case .natural:
            isSynthesizing = true
            speakNatural(stripped, messageId: messageId, voice: voice)
        }
    }

    func stop() {
        standardSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        pendingMessageId = nil
        isSynthesizing = false
        isPlaying = false
        playingMessageId = nil
    }

    func playAudio(_ data: Data, messageId: String) {
        guard pendingMessageId == messageId else { return }
        pendingMessageId = nil
        isSynthesizing = false

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.enableRate = true
            audioPlayer?.rate = 1.25
            audioPlayer?.play()

            Task {
                while audioPlayer?.isPlaying == true {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                isPlaying = false
                playingMessageId = nil
            }
        } catch {
            isPlaying = false
            playingMessageId = nil
        }
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

    private func speakNatural(_ text: String, messageId: String, voice: String?) {
        pendingMessageId = messageId
        onSynthesizeRequest?(text, messageId, voice)
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
