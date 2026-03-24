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
            let query = try container.decode(String.self, forKey: .query)
            return .fileSearchResults(files: files, query: query)
        case "remote_session_list":
            let sessions = try container.decode([RemoteSession].self, forKey: .sessions)
            return .remoteSessionList(sessions: sessions)
        case "message_uuid":
            let uuid = try container.decode(String.self, forKey: .uuid)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .messageUUID(uuid: uuid, conversationId: conversationId)
        case "team_created":
            let teamName = try container.decode(String.self, forKey: .teamName)
            let leadAgentId = try container.decode(String.self, forKey: .leadAgentId)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .teamCreated(teamName: teamName, leadAgentId: leadAgentId, conversationId: conversationId)
        case "teammate_spawned":
            let teammate = try container.decode(TeammateInfo.self, forKey: .teammate)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .teammateSpawned(teammate: teammate, conversationId: conversationId)
        case "teammate_update":
            let teammateId = try container.decode(String.self, forKey: .teammateId)
            let status = try container.decodeIfPresent(TeammateStatus.self, forKey: .status)
            let lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage)
            let lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .teammateUpdate(teammateId: teammateId, status: status, lastMessage: lastMessage, lastMessageAt: lastMessageAt, conversationId: conversationId)
        case "team_deleted":
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .teamDeleted(conversationId: conversationId)
        case "name_suggestion":
            let name = try container.decode(String.self, forKey: .name)
            let symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            return .nameSuggestion(name: name, symbol: symbol, conversationId: conversationId)
        case "plans":
            let stages = try container.decode([String: [PlanItem]].self, forKey: .stages)
            return .plans(stages: stages)
        case "plan_deleted":
            let stage = try container.decode(String.self, forKey: .stage)
            let filename = try container.decode(String.self, forKey: .filename)
            return .planDeleted(stage: stage, filename: filename)
        case "usage_stats":
            let stats = try container.decode(UsageStats.self, forKey: .stats)
            return .usageStats(stats: stats)
        case "terminal_output":
            let output = try container.decode(String.self, forKey: .output)
            let exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
            let isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            let terminalId = try container.decodeIfPresent(String.self, forKey: .terminalId)
            return .terminalOutput(output: output, exitCode: exitCode, isError: isError, terminalId: terminalId)
        case "branch_attached":
            let branch = try container.decode(String.self, forKey: .branch)
            let worktreePath = try container.decode(String.self, forKey: .worktreePath)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .branchAttached(branch: branch, worktreePath: worktreePath, conversationId: conversationId)
        case "branch_list":
            let branches = try container.decode([String].self, forKey: .branches)
            let current = try container.decode(String.self, forKey: .current)
            return .branchList(branches: branches, current: current)
        default:
            return nil
        }
    }
}
