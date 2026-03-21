import Foundation
import CloudeShared

extension ClaudeCodeRunner {
    func parseTeamResult(from block: [String: Any]) {
        guard let contentBlocks = block["content"] as? [[String: Any]] else { return }
        for sub in contentBlocks {
            guard sub["type"] as? String == "text", let text = sub["text"] as? String else { continue }

            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let teamName = json["team_name"] as? String,
                   let leadAgentId = json["lead_agent_id"] as? String,
                   json["team_file_path"] != nil {
                    onTeamCreated?(teamName, leadAgentId)
                }

                if let success = json["success"] as? Bool, success,
                   let message = json["message"] as? String,
                   message.contains("Cleaned up") {
                    onTeamDeleted?()
                }
                continue
            }

            if text.contains("Spawned successfully") && text.contains("agent_id:") {
                let fields = parseKeyValueLines(text)
                guard let agentId = fields["agent_id"],
                      let name = fields["name"],
                      let teamName = fields["team_name"] else { continue }
                let member = lookupTeamMember(agentId: agentId, teamName: teamName)
                let model = member?["model"] as? String ?? "unknown"
                let color = member?["color"] as? String ?? "gray"
                let agentType = member?["agentType"] as? String ?? "general-purpose"
                let teammate = TeammateInfo(id: agentId, name: name, agentType: agentType, model: model, color: color)
                onTeammateSpawned?(teammate)
            }
        }
    }

    func extractResultInfo(from block: [String: Any]) -> (summary: String?, output: String?) {
        let fullText: String? = {
            if let content = block["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            if let contentBlocks = block["content"] as? [[String: Any]] {
                let texts = contentBlocks.compactMap { sub -> String? in
                    guard sub["type"] as? String == "text", let text = sub["text"] as? String else { return nil }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
                return texts.isEmpty ? nil : texts.joined(separator: "\n")
            }
            return nil
        }()

        guard let text = fullText else { return (nil, nil) }

        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let summary: String
        if firstLine.count > 80 {
            summary = String(firstLine.prefix(77)) + "..."
        } else {
            summary = firstLine
        }

        let maxOutputLength = 5000
        let output: String
        if text.count > maxOutputLength {
            output = String(text.prefix(maxOutputLength))
        } else {
            output = text
        }

        return (summary, output)
    }

    private func parseKeyValueLines(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            result[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    private func lookupTeamMember(agentId: String, teamName: String) -> [String: Any]? {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/teams/\(teamName)/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let members = config["members"] as? [[String: Any]] else { return nil }
        return members.first { ($0["agentId"] as? String) == agentId }
    }
}
