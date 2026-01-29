//
//  ServerMessage.swift
//  Cloude Agent
//

import Foundation

enum ServerMessage: Codable {
    case output(text: String)
    case fileChange(path: String, diff: String?, content: String?)
    case image(path: String, base64: String)
    case status(state: AgentState)
    case authRequired
    case authResult(success: Bool, message: String?)
    case error(message: String)
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64)
    case sessionId(id: String)
    case missedResponse(sessionId: String, text: String, completedAt: Date)
    case noMissedResponse(sessionId: String)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?)
    case runStats(durationMs: Int, costUsd: Double)
    case gitStatusResult(status: GitStatusInfo)
    case gitDiffResult(path: String, diff: String)
    case gitCommitResult(success: Bool, message: String?)

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, content, base64, state, success, message, entries, data, mimeType, size, id, sessionId, completedAt, name, input, status, branch, ahead, behind, files, durationMs, costUsd, toolId, parentToolId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "output":
            let text = try container.decode(String.self, forKey: .text)
            self = .output(text: text)
        case "file_change":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decodeIfPresent(String.self, forKey: .diff)
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            self = .fileChange(path: path, diff: diff, content: content)
        case "image":
            let path = try container.decode(String.self, forKey: .path)
            let base64 = try container.decode(String.self, forKey: .base64)
            self = .image(path: path, base64: base64)
        case "status":
            let state = try container.decode(AgentState.self, forKey: .state)
            self = .status(state: state)
        case "auth_required":
            self = .authRequired
        case "auth_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .authResult(success: success, message: message)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "directory_listing":
            let path = try container.decode(String.self, forKey: .path)
            let entries = try container.decode([FileEntry].self, forKey: .entries)
            self = .directoryListing(path: path, entries: entries)
        case "file_content":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            self = .fileContent(path: path, data: data, mimeType: mimeType, size: size)
        case "session_id":
            let id = try container.decode(String.self, forKey: .id)
            self = .sessionId(id: id)
        case "missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let text = try container.decode(String.self, forKey: .text)
            let completedAt = try container.decode(Date.self, forKey: .completedAt)
            self = .missedResponse(sessionId: sessionId, text: text, completedAt: completedAt)
        case "no_missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .noMissedResponse(sessionId: sessionId)
        case "tool_call":
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent(String.self, forKey: .input)
            let toolId = try container.decode(String.self, forKey: .toolId)
            let parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
            self = .toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId)
        case "run_stats":
            let durationMs = try container.decode(Int.self, forKey: .durationMs)
            let costUsd = try container.decode(Double.self, forKey: .costUsd)
            self = .runStats(durationMs: durationMs, costUsd: costUsd)
        case "git_status_result":
            let status = try container.decode(GitStatusInfo.self, forKey: .status)
            self = .gitStatusResult(status: status)
        case "git_diff_result":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decode(String.self, forKey: .diff)
            self = .gitDiffResult(path: path, diff: diff)
        case "git_commit_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .gitCommitResult(success: success, message: message)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

}
