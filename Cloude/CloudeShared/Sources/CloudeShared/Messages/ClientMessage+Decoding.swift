import Foundation

extension ClientMessage {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "chat":
            let message = try container.decode(String.self, forKey: .message)
            let workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
            let sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
            let isNewSession = try container.decodeIfPresent(Bool.self, forKey: .isNewSession) ?? true
            var imagesBase64 = try container.decodeIfPresent([String].self, forKey: .imagesBase64)
            if imagesBase64 == nil, let single = try container.decodeIfPresent(String.self, forKey: .imageBase64) {
                imagesBase64 = [single]
            }
            let filesBase64 = try container.decodeIfPresent([AttachedFilePayload].self, forKey: .filesBase64)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let conversationName = try container.decodeIfPresent(String.self, forKey: .conversationName)
            let forkSession = try container.decodeIfPresent(Bool.self, forKey: .forkSession) ?? false
            let effort = try container.decodeIfPresent(String.self, forKey: .effort)
            let model = try container.decodeIfPresent(String.self, forKey: .model)
            self = .chat(message: message, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model)
        case "abort":
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .abort(conversationId: conversationId)
        case "auth":
            let token = try container.decode(String.self, forKey: .token)
            self = .auth(token: token)
        case "list_directory":
            let path = try container.decode(String.self, forKey: .path)
            self = .listDirectory(path: path)
        case "get_file":
            let path = try container.decode(String.self, forKey: .path)
            self = .getFile(path: path)
        case "get_file_full_quality":
            let path = try container.decode(String.self, forKey: .path)
            self = .getFileFullQuality(path: path)
        case "resume_from":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let lastSeq = try container.decode(Int.self, forKey: .lastSeq)
            self = .resumeFrom(sessionId: sessionId, lastSeq: lastSeq)
        case "git_status":
            let path = try container.decode(String.self, forKey: .path)
            self = .gitStatus(path: path)
        case "git_diff":
            let path = try container.decode(String.self, forKey: .path)
            let file = try container.decodeIfPresent(String.self, forKey: .file)
            let staged = try container.decodeIfPresent(Bool.self, forKey: .staged) ?? false
            self = .gitDiff(path: path, file: file, staged: staged)
        case "git_commit":
            let path = try container.decode(String.self, forKey: .path)
            let message = try container.decode(String.self, forKey: .message)
            let files = try container.decode([String].self, forKey: .files)
            self = .gitCommit(path: path, message: message, files: files)
        case "git_log":
            let path = try container.decode(String.self, forKey: .path)
            let count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 10
            self = .gitLog(path: path, count: count)
        case "transcribe":
            let audioBase64 = try container.decode(String.self, forKey: .audioBase64)
            self = .transcribe(audioBase64: audioBase64)
        case "get_processes":
            self = .getProcesses
        case "kill_process":
            let pid = try container.decode(Int32.self, forKey: .pid)
            self = .killProcess(pid: pid)
        case "sync_history":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
        case "search_files":
            let query = try container.decode(String.self, forKey: .query)
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .searchFiles(query: query, workingDirectory: workingDirectory)
        case "suggest_name":
            let text = try container.decode(String.self, forKey: .text)
            let context = try container.decodeIfPresent([String].self, forKey: .context) ?? []
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            self = .suggestName(text: text, context: context, conversationId: conversationId)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }
}
