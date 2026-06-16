import Foundation
import SwiftData

enum ChatInputSuggestionService {
    static func fileSuggestions(
        sessionId: UUID, query: String, context: ModelContext
    ) async -> [ChatInputSuggestion] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId })
        if let session = try? context.fetch(descriptor).first,
            let endpoint = session.endpoint, let path = session.path, !path.isEmpty,
            let files = await FilesService.search(
                endpoint: endpoint, session: session, root: path, query: query)
        {
            return ChatInputAutocomplete.fileSuggestions(
                files.filter { !$0.isDirectory }.map { $0.path })
        }
        return []
    }
}
