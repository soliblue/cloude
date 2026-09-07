import Foundation

struct SessionRemoteThread: Decodable, Identifiable {
    let id: String
    let cwd: String
    let preview: String
    let name: String?
    let updatedAt: Double
    let agentNickname: String?
    let agentPath: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SessionRemoteThreadKey.self)
        id = try container.decode(String.self, forKey: .id)
        cwd = try container.decode(String.self, forKey: .cwd)
        preview = try container.decode(String.self, forKey: .preview)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        updatedAt = try container.decode(Double.self, forKey: .updatedAt)
        let source = try? container.nestedContainer(keyedBy: SessionRemoteThreadKey.self, forKey: .source)
        let agent = try? source?.nestedContainer(keyedBy: SessionRemoteThreadKey.self, forKey: .subAgent)
        let spawn = try? agent?.nestedContainer(keyedBy: SessionRemoteThreadKey.self, forKey: .threadSpawn)
        agentNickname =
            try container.decodeIfPresent(String.self, forKey: .agentNickname)
            ?? spawn?.decodeIfPresent(String.self, forKey: .nestedNickname)
        agentPath = try spawn?.decodeIfPresent(String.self, forKey: .agentPath)
    }

    var title: String {
        [name, preview, agentNickname, agentPath?.split(separator: "/").last.map(String.init)].compactMap {
            $0?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .first(where: { !$0.isEmpty }).map { String($0.prefix(100)) } ?? "Untitled Codex chat"
    }
}
