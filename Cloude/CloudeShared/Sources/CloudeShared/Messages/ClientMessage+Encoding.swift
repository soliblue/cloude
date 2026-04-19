import Foundation

extension ClientMessage {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chat(let message, let workingDirectory, let sessionId, let isNewSession, let imagesBase64, let filesBase64, let conversationId, let conversationName, let forkSession, let effort, let model):
            try container.encode("chat", forKey: .type)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
            try container.encodeIfPresent(sessionId, forKey: .sessionId)
            try container.encode(isNewSession, forKey: .isNewSession)
            try container.encodeIfPresent(imagesBase64, forKey: .imagesBase64)
            try container.encodeIfPresent(filesBase64, forKey: .filesBase64)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(conversationName, forKey: .conversationName)
            try container.encode(forkSession, forKey: .forkSession)
            try container.encodeIfPresent(effort, forKey: .effort)
            try container.encodeIfPresent(model, forKey: .model)
        case .abort(let conversationId):
            try container.encode("abort", forKey: .type)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .auth(let token):
            try container.encode("auth", forKey: .type)
            try container.encode(token, forKey: .token)
        case .listDirectory(let path):
            try container.encode("list_directory", forKey: .type)
            try container.encode(path, forKey: .path)
        case .getFile(let path):
            try container.encode("get_file", forKey: .type)
            try container.encode(path, forKey: .path)
        case .getFileFullQuality(let path):
            try container.encode("get_file_full_quality", forKey: .type)
            try container.encode(path, forKey: .path)
        case .requestMissedResponse(let sessionId):
            try container.encode("request_missed_response", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
        case .resumeFrom(let sessionId, let lastSeq):
            try container.encode("resume_from", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(lastSeq, forKey: .lastSeq)
        case .gitStatus(let path):
            try container.encode("git_status", forKey: .type)
            try container.encode(path, forKey: .path)
        case .gitDiff(let path, let file, let staged):
            try container.encode("git_diff", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(file, forKey: .file)
            if staged { try container.encode(true, forKey: .staged) }
        case .gitCommit(let path, let message, let files):
            try container.encode("git_commit", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(message, forKey: .message)
            try container.encode(files, forKey: .files)
        case .gitLog(let path, let count):
            try container.encode("git_log", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(count, forKey: .count)
        case .transcribe(let audioBase64):
            try container.encode("transcribe", forKey: .type)
            try container.encode(audioBase64, forKey: .audioBase64)
        case .getProcesses:
            try container.encode("get_processes", forKey: .type)
        case .killProcess(let pid):
            try container.encode("kill_process", forKey: .type)
            try container.encode(pid, forKey: .pid)
        case .syncHistory(let sessionId, let workingDirectory):
            try container.encode("sync_history", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .searchFiles(let query, let workingDirectory):
            try container.encode("search_files", forKey: .type)
            try container.encode(query, forKey: .query)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .suggestName(let text, let context, let conversationId):
            try container.encode("suggest_name", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(context, forKey: .context)
            try container.encode(conversationId, forKey: .conversationId)
        case .ping(let sentAt):
            try container.encode("ping", forKey: .type)
            try container.encode(sentAt, forKey: .sentAt)
        }
    }
}
