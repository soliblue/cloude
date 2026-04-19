import Foundation

extension ServerMessage {
    static func decodeExtendedTypes(type: String, container: KeyedDecodingContainer<CodingKeys>) throws -> Self? {
        switch type {
        case "process_list":
            let processes = try container.decode([AgentProcessInfo].self, forKey: .processes)
            return .processList(processes: processes)
        case "default_working_directory":
            let path = try container.decode(String.self, forKey: .path)
            return .defaultWorkingDirectory(path: path)
        case "skills":
            let skills = try container.decode([Skill].self, forKey: .skills)
            return .skills(skills)
        case "history_sync":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let messages = try container.decode([HistoryMessage].self, forKey: .messages)
            return .historySync(sessionId: sessionId, messages: messages)
        case "history_sync_error":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let error = try container.decode(String.self, forKey: .error)
            return .historySyncError(sessionId: sessionId, error: error)
        case "file_chunk":
            let path = try container.decode(String.self, forKey: .path)
            let chunkIndex = try container.decode(Int.self, forKey: .chunkIndex)
            let totalChunks = try container.decode(Int.self, forKey: .totalChunks)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            return .fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size)
        case "file_thumbnail":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let fullSize = try container.decode(Int64.self, forKey: .fullSize)
            return .fileThumbnail(path: path, data: data, fullSize: fullSize)
        case "file_search_results":
            let files = try container.decode([String].self, forKey: .files)
            return .fileSearchResults(files: files)
        case "message_uuid":
            let uuid = try container.decode(String.self, forKey: .uuid)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .messageUUID(uuid: uuid, conversationId: conversationId)
        case "team_created", "teammate_spawned", "teammate_update", "team_deleted":
            return nil
        case "name_suggestion":
            let name = try container.decode(String.self, forKey: .name)
            let symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            return .nameSuggestion(name: name, symbol: symbol, conversationId: conversationId)
        case "resume_from_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let events = try container.decode([ReplayedEvent].self, forKey: .events)
            let historyOnly = try container.decode(Bool.self, forKey: .historyOnly)
            return .resumeFromResponse(sessionId: sessionId, events: events, historyOnly: historyOnly)
        default:
            return nil
        }
    }
}
