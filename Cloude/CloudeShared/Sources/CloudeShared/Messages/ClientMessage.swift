import Foundation

public enum ClientMessage: Codable {
    case chat(message: String, workingDirectory: String?, sessionId: String?, isNewSession: Bool, imageBase64: String?, conversationId: String?)
    case abort(conversationId: String?)
    case auth(token: String)
    case listDirectory(path: String)
    case getFile(path: String)
    case requestMissedResponse(sessionId: String)
    case gitStatus(path: String)
    case gitDiff(path: String, file: String?)
    case gitCommit(path: String, message: String, files: [String])
    case transcribe(audioBase64: String)
    case setHeartbeatInterval(minutes: Int?)
    case getHeartbeatConfig
    case markHeartbeatRead
    case triggerHeartbeat
    case getMemories
    case getProcesses
    case killProcess(pid: Int32)
    case killAllProcesses
    case syncHistory(sessionId: String, workingDirectory: String)

    enum CodingKeys: String, CodingKey {
        case type, message, workingDirectory, token, path, sessionId, isNewSession, file, files, imageBase64, audioBase64, conversationId, minutes, pid
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
            let imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .chat(message: message, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64, conversationId: conversationId)
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
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chat(let message, let workingDirectory, let sessionId, let isNewSession, let imageBase64, let conversationId):
            try container.encode("chat", forKey: .type)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
            try container.encodeIfPresent(sessionId, forKey: .sessionId)
            try container.encode(isNewSession, forKey: .isNewSession)
            try container.encodeIfPresent(imageBase64, forKey: .imageBase64)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
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
        }
    }
}
