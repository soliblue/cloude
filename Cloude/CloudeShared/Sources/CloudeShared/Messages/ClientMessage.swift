import Foundation

public struct AttachedFilePayload: Codable {
    public let name: String
    public let data: String

    public init(name: String, data: String) {
        self.name = name
        self.data = data
    }
}

public enum ClientMessage: Codable {
    case chat(message: String, workingDirectory: String?, sessionId: String?, isNewSession: Bool, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]?, conversationId: String?, conversationName: String?, forkSession: Bool, effort: String?, model: String?)
    case abort(conversationId: String?)
    case auth(token: String)
    case listDirectory(path: String)
    case getFile(path: String)
    case getFileFullQuality(path: String)
    case requestMissedResponse(sessionId: String)
    case gitStatus(path: String)
    case gitDiff(path: String, file: String?)
    case gitCommit(path: String, message: String, files: [String])
    case transcribe(audioBase64: String)
    case synthesize(text: String, messageId: String, voice: String?)
    case setHeartbeatInterval(minutes: Int?)
    case getHeartbeatConfig
    case markHeartbeatRead
    case triggerHeartbeat
    case getMemories
    case getProcesses
    case killProcess(pid: Int32)
    case killAllProcesses
    case syncHistory(sessionId: String, workingDirectory: String)
    case searchFiles(query: String, workingDirectory: String)
    case listRemoteSessions(workingDirectory: String)
    case requestSuggestions(context: [String], workingDirectory: String?, conversationId: String?)
    case suggestName(text: String, context: [String], conversationId: String)
    case getPlans(workingDirectory: String)
    case deletePlan(stage: String, filename: String, workingDirectory: String)

    enum CodingKeys: String, CodingKey {
        case type, message, workingDirectory, token, path, sessionId, isNewSession, file, files, imageBase64, imagesBase64, filesBase64, audioBase64, conversationId, conversationName, minutes, pid, forkSession, query, effort, model, text, context, stage, filename, content, messageId, voice
    }

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
        case "request_missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .requestMissedResponse(sessionId: sessionId)
        case "git_status":
            let path = try container.decode(String.self, forKey: .path)
            self = .gitStatus(path: path)
        case "git_diff":
            let path = try container.decode(String.self, forKey: .path)
            let file = try container.decodeIfPresent(String.self, forKey: .file)
            self = .gitDiff(path: path, file: file)
        case "git_commit":
            let path = try container.decode(String.self, forKey: .path)
            let message = try container.decode(String.self, forKey: .message)
            let files = try container.decode([String].self, forKey: .files)
            self = .gitCommit(path: path, message: message, files: files)
        case "transcribe":
            let audioBase64 = try container.decode(String.self, forKey: .audioBase64)
            self = .transcribe(audioBase64: audioBase64)
        case "synthesize":
            let text = try container.decode(String.self, forKey: .text)
            let messageId = try container.decode(String.self, forKey: .messageId)
            let voice = try container.decodeIfPresent(String.self, forKey: .voice)
            self = .synthesize(text: text, messageId: messageId, voice: voice)
        case "set_heartbeat_interval":
            let minutes = try container.decodeIfPresent(Int.self, forKey: .minutes)
            self = .setHeartbeatInterval(minutes: minutes)
        case "get_heartbeat_config":
            self = .getHeartbeatConfig
        case "mark_heartbeat_read":
            self = .markHeartbeatRead
        case "trigger_heartbeat":
            self = .triggerHeartbeat
        case "get_memories":
            self = .getMemories
        case "get_processes":
            self = .getProcesses
        case "kill_process":
            let pid = try container.decode(Int32.self, forKey: .pid)
            self = .killProcess(pid: pid)
        case "kill_all_processes":
            self = .killAllProcesses
        case "sync_history":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
        case "search_files":
            let query = try container.decode(String.self, forKey: .query)
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .searchFiles(query: query, workingDirectory: workingDirectory)
        case "list_remote_sessions":
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .listRemoteSessions(workingDirectory: workingDirectory)
        case "request_suggestions":
            let context = try container.decodeIfPresent([String].self, forKey: .context) ?? []
            let workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .requestSuggestions(context: context, workingDirectory: workingDirectory, conversationId: conversationId)
        case "suggest_name":
            let text = try container.decode(String.self, forKey: .text)
            let context = try container.decodeIfPresent([String].self, forKey: .context) ?? []
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            self = .suggestName(text: text, context: context, conversationId: conversationId)
        case "get_plans":
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .getPlans(workingDirectory: workingDirectory)
        case "delete_plan":
            let stage = try container.decode(String.self, forKey: .stage)
            let filename = try container.decode(String.self, forKey: .filename)
            let workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
            self = .deletePlan(stage: stage, filename: filename, workingDirectory: workingDirectory)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

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
        case .gitStatus(let path):
            try container.encode("git_status", forKey: .type)
            try container.encode(path, forKey: .path)
        case .gitDiff(let path, let file):
            try container.encode("git_diff", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(file, forKey: .file)
        case .gitCommit(let path, let message, let files):
            try container.encode("git_commit", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(message, forKey: .message)
            try container.encode(files, forKey: .files)
        case .transcribe(let audioBase64):
            try container.encode("transcribe", forKey: .type)
            try container.encode(audioBase64, forKey: .audioBase64)
        case .synthesize(let text, let messageId, let voice):
            try container.encode("synthesize", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(messageId, forKey: .messageId)
            try container.encodeIfPresent(voice, forKey: .voice)
        case .setHeartbeatInterval(let minutes):
            try container.encode("set_heartbeat_interval", forKey: .type)
            try container.encodeIfPresent(minutes, forKey: .minutes)
        case .getHeartbeatConfig:
            try container.encode("get_heartbeat_config", forKey: .type)
        case .markHeartbeatRead:
            try container.encode("mark_heartbeat_read", forKey: .type)
        case .triggerHeartbeat:
            try container.encode("trigger_heartbeat", forKey: .type)
        case .getMemories:
            try container.encode("get_memories", forKey: .type)
        case .getProcesses:
            try container.encode("get_processes", forKey: .type)
        case .killProcess(let pid):
            try container.encode("kill_process", forKey: .type)
            try container.encode(pid, forKey: .pid)
        case .killAllProcesses:
            try container.encode("kill_all_processes", forKey: .type)
        case .syncHistory(let sessionId, let workingDirectory):
            try container.encode("sync_history", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .searchFiles(let query, let workingDirectory):
            try container.encode("search_files", forKey: .type)
            try container.encode(query, forKey: .query)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .listRemoteSessions(let workingDirectory):
            try container.encode("list_remote_sessions", forKey: .type)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .requestSuggestions(let context, let workingDirectory, let conversationId):
            try container.encode("request_suggestions", forKey: .type)
            try container.encode(context, forKey: .context)
            try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .suggestName(let text, let context, let conversationId):
            try container.encode("suggest_name", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(context, forKey: .context)
            try container.encode(conversationId, forKey: .conversationId)
        case .getPlans(let workingDirectory):
            try container.encode("get_plans", forKey: .type)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        case .deletePlan(let stage, let filename, let workingDirectory):
            try container.encode("delete_plan", forKey: .type)
            try container.encode(stage, forKey: .stage)
            try container.encode(filename, forKey: .filename)
            try container.encode(workingDirectory, forKey: .workingDirectory)
        }
    }
}
