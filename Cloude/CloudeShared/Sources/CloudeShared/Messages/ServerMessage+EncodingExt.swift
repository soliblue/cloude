import Foundation

extension ServerMessage {
    func encodeExtendedCases(_ container: inout KeyedEncodingContainer<CodingKeys>) throws {
        switch self {
        case .processList(let processes):
            try container.encode("process_list", forKey: .type)
            try container.encode(processes, forKey: .processes)
        case .defaultWorkingDirectory(let path):
            try container.encode("default_working_directory", forKey: .type)
            try container.encode(path, forKey: .path)
        case .skills(let skills):
            try container.encode("skills", forKey: .type)
            try container.encode(skills, forKey: .skills)
        case .historySync(let sessionId, let messages):
            try container.encode("history_sync", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(messages, forKey: .messages)
        case .historySyncError(let sessionId, let error):
            try container.encode("history_sync_error", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(error, forKey: .error)
        case .fileChunk(let path, let chunkIndex, let totalChunks, let data, let mimeType, let size):
            try container.encode("file_chunk", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(chunkIndex, forKey: .chunkIndex)
            try container.encode(totalChunks, forKey: .totalChunks)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
        case .fileThumbnail(let path, let data, let fullSize):
            try container.encode("file_thumbnail", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(data, forKey: .data)
            try container.encode(fullSize, forKey: .fullSize)
        case .fileSearchResults(let files, let query):
            try container.encode("file_search_results", forKey: .type)
            try container.encode(files, forKey: .files)
            try container.encode(query, forKey: .query)
        case .remoteSessionList(let sessions):
            try container.encode("remote_session_list", forKey: .type)
            try container.encode(sessions, forKey: .sessions)
        case .messageUUID(let uuid, let conversationId):
            try container.encode("message_uuid", forKey: .type)
            try container.encode(uuid, forKey: .uuid)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .nameSuggestion(let name, let symbol, let conversationId):
            try container.encode("name_suggestion", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(symbol, forKey: .symbol)
            try container.encode(conversationId, forKey: .conversationId)
        case .plans(let stages):
            try container.encode("plans", forKey: .type)
            try container.encode(stages, forKey: .stages)
        case .planDeleted(let stage, let filename):
            try container.encode("plan_deleted", forKey: .type)
            try container.encode(stage, forKey: .stage)
            try container.encode(filename, forKey: .filename)
        case .usageStats(let stats):
            try container.encode("usage_stats", forKey: .type)
            try container.encode(stats, forKey: .stats)
        case .terminalOutput(let output, let exitCode, let isError, let terminalId):
            try container.encode("terminal_output", forKey: .type)
            try container.encode(output, forKey: .output)
            try container.encodeIfPresent(exitCode, forKey: .exitCode)
            try container.encode(isError, forKey: .isError)
            try container.encodeIfPresent(terminalId, forKey: .terminalId)
        case .pong(let sentAt, let serverAt):
            try container.encode("pong", forKey: .type)
            try container.encode(sentAt, forKey: .sentAt)
            try container.encode(serverAt, forKey: .serverAt)
        default:
            break
        }
    }
}
