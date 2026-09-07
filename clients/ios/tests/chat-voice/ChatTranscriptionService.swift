import Foundation

@MainActor enum ChatTranscriptionService {
    static var continuation: CheckedContinuation<String?, Never>?
    static func transcribe(endpoint: Endpoint, sessionId: UUID, audio: Data) async -> String? {
        await withCheckedContinuation { continuation = $0 }
    }
}
