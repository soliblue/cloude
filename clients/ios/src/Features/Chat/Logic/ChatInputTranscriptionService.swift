import Foundation
import SwiftData

enum ChatInputTranscriptionService {
    static func transcribe(sessionId: UUID, audio: Data, context: ModelContext) async -> String? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId })
        if let session = try? context.fetch(descriptor).first,
            let endpoint = session.endpoint,
            let text = await ChatTranscriptionService.transcribe(
                endpoint: endpoint, sessionId: sessionId, audio: audio),
            !text.isEmpty
        {
            return text
        }
        return nil
    }
}
