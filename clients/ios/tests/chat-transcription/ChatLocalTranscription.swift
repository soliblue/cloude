import Foundation

@MainActor final class ChatLocalTranscription {
    static var available = true
    static var result: String?
    static var calls = 0
    static var beforeReturn: (() async -> Void)?
    func transcribe(audio: Data) async -> String? {
        Self.calls += 1
        await Self.beforeReturn?()
        return Self.result
    }
}
