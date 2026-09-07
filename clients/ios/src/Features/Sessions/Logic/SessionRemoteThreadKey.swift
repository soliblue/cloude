import Foundation

enum SessionRemoteThreadKey: String, CodingKey {
    case id, cwd, preview, name, updatedAt, agentNickname, source, subAgent
    case threadSpawn = "thread_spawn"
    case agentPath = "agent_path"
    case nestedNickname = "agent_nickname"
}
