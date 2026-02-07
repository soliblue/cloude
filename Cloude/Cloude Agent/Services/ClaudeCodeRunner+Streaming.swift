import Foundation
import Combine
import CloudeShared

extension ClaudeCodeRunner {
    func processStreamLines(_ text: String) {
        lineBuffer += text
        let lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.last ?? ""

        for line in lines.dropLast() {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let type = json["type"] as? String ?? ""

            if type == "system",
               let subtype = json["subtype"] as? String {
                if subtype == "init", let sessionId = json["session_id"] as? String {
                    events.send(.sessionId(sessionId))
                    onSessionId?(sessionId)
                }
                if subtype == "status", let status = json["status"] as? String {
                    if status == "compacting" {
                        events.send(.status(.compacting))
                        onStatus?(.compacting)
                    }
                }
            }

            if type == "stream_event",
               let event = json["event"] as? [String: Any],
               let eventType = event["type"] as? String {
                if eventType == "content_block_start" {
                    if !accumulatedOutput.isEmpty && !accumulatedOutput.hasSuffix("\n") {
                        accumulatedOutput += "\n\n"
                        onOutput?("\n\n")
                    }
                }
                if eventType == "content_block_delta",
                   let delta = event["delta"] as? [String: Any],
                   let deltaText = delta["text"] as? String {
                    accumulatedOutput += deltaText
                    events.send(.output(deltaText))
                    onOutput?(deltaText)
                }
            }

            if type == "content_block_start" {
                if !accumulatedOutput.isEmpty && !accumulatedOutput.hasSuffix("\n") {
                    accumulatedOutput += "\n\n"
                    onOutput?("\n\n")
                }
            }

            if type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let deltaText = delta["text"] as? String {
                accumulatedOutput += deltaText
                events.send(.output(deltaText))
                onOutput?(deltaText)
            }

            let parentToolUseId = json["parent_tool_use_id"] as? String

            if type == "assistant",
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                if let uuid = json["uuid"] as? String {
                    onMessageUUID?(uuid)
                }
                for block in content {
                    if block["type"] as? String == "text",
                       let blockText = block["text"] as? String {
                        if !accumulatedOutput.contains(blockText) {
                            accumulatedOutput += blockText
                            onOutput?(blockText)
                        }
                    }
                    if block["type"] as? String == "tool_use",
                       let toolName = block["name"] as? String,
                       let toolId = block["id"] as? String {
                        let input = extractToolInput(name: toolName, input: block["input"] as? [String: Any])
                        let textPosition = accumulatedOutput.count
                        events.send(.toolCall(name: toolName, input: input, toolId: toolId, parentToolId: parentToolUseId))
                        onToolCall?(toolName, input, toolId, parentToolUseId, textPosition)
                    }
                }
            }

            if type == "user",
               let message = json["message"] as? [String: Any] {
                if let content = message["content"] as? String {
                    if content.hasPrefix("<local-command-stdout>") && content.hasSuffix("</local-command-stdout>") {
                        let start = content.index(content.startIndex, offsetBy: "<local-command-stdout>".count)
                        let end = content.index(content.endIndex, offsetBy: -"</local-command-stdout>".count)
                        let extracted = String(content[start..<end])
                        accumulatedOutput += extracted
                        events.send(.output(extracted))
                        onOutput?(extracted)
                    }
                } else if let contentBlocks = message["content"] as? [[String: Any]] {
                    for block in contentBlocks {
                        if block["type"] as? String == "tool_result",
                           let toolUseId = block["tool_use_id"] as? String {
                            let summary = extractResultSummary(from: block)
                            events.send(.toolResult(toolId: toolUseId, summary: summary))
                            onToolResult?(toolUseId, summary)
                            parseTeamResult(from: block)
                        }
                    }
                }
            }

            if type == "result" {
                if let sessionId = json["session_id"] as? String {
                    events.send(.sessionId(sessionId))
                    onSessionId?(sessionId)
                }
                if let durationMs = json["duration_ms"] as? Int,
                   let costUsd = json["total_cost_usd"] as? Double {
                    pendingRunStats = (durationMs, costUsd)
                }
                if let result = json["result"] as? String, accumulatedOutput.isEmpty {
                    events.send(.output(result))
                    onOutput?(result)
                }
            }
        }
    }

    func drainPipesAndComplete() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        if let data = outputPipe?.fileHandleForReading.readDataToEndOfFile(),
           !data.isEmpty,
           let text = String(data: data, encoding: .utf8) {
            processStreamLines(text)
        }

        if let data = errorPipe?.fileHandleForReading.readDataToEndOfFile(),
           !data.isEmpty,
           let text = String(data: data, encoding: .utf8) {
            onOutput?(text)
        }

        process = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
        accumulatedOutput = ""
        lineBuffer = ""
        commandBuffer = ""

        if let stats = pendingRunStats {
            events.send(.runStats(durationMs: stats.durationMs, costUsd: stats.costUsd))
            onRunStats?(stats.durationMs, stats.costUsd)
            pendingRunStats = nil
        }

        events.send(.complete)
        onComplete?()
    }

    func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
        accumulatedOutput = ""
        lineBuffer = ""
        commandBuffer = ""
        pendingRunStats = nil

        for imagePath in tempImagePaths {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        tempImagePaths = []
    }

    private func parseTeamResult(from block: [String: Any]) {
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

    private func parseKeyValueLines(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            result[key] = value
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

    private func extractResultSummary(from block: [String: Any]) -> String? {
        if let content = block["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            if firstLine.count > 80 {
                return String(firstLine.prefix(77)) + "..."
            }
            return firstLine
        }
        if let contentBlocks = block["content"] as? [[String: Any]] {
            for sub in contentBlocks {
                if sub["type"] as? String == "text", let text = sub["text"] as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
                    if firstLine.count > 80 {
                        return String(firstLine.prefix(77)) + "..."
                    }
                    return firstLine
                }
            }
        }
        return nil
    }

    private func extractToolInput(name: String, input: [String: Any]?) -> String? {
        extractToolInputString(name: name, input: input)
    }

    private func extractCloudeCommands(_ text: String) -> String {
        commandBuffer += text

        let pattern = #"\[\[cloude:(\w+):([^\]]*)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            let output = commandBuffer
            commandBuffer = ""
            return output
        }

        var result = ""
        var lastEnd = commandBuffer.startIndex

        let range = NSRange(commandBuffer.startIndex..., in: commandBuffer)
        let matches = regex.matches(in: commandBuffer, range: range)

        if !matches.isEmpty {
            Log.info("Found \(matches.count) cloude command(s) in buffer")
        }

        for match in matches {
            guard let fullRange = Range(match.range, in: commandBuffer),
                  let actionRange = Range(match.range(at: 1), in: commandBuffer),
                  let valueRange = Range(match.range(at: 2), in: commandBuffer) else { continue }

            result += commandBuffer[lastEnd..<fullRange.lowerBound]

            let action = String(commandBuffer[actionRange])
            let value = String(commandBuffer[valueRange])
            Log.info("Executing cloude command: \(action) = \(value)")
            onCloudeCommand?(action, value)

            lastEnd = fullRange.upperBound
        }

        if commandBuffer.contains("[[cloude:") && !commandBuffer.contains("]]") {
            if let startIdx = commandBuffer.range(of: "[[cloude:")?.lowerBound {
                result += commandBuffer[lastEnd..<startIdx]
                commandBuffer = String(commandBuffer[startIdx...])
                Log.info("Buffering partial command: \(commandBuffer)")
                return result
            }
        }

        result += commandBuffer[lastEnd...]
        commandBuffer = ""
        return result
    }
}

func extractToolInputString(name: String, input: [String: Any]?) -> String? {
    switch name {
    case "Bash":
        return input?["command"] as? String
    case "Read", "Write", "Edit":
        return input?["file_path"] as? String
    case "Glob":
        return input?["pattern"] as? String
    case "Grep":
        return input?["pattern"] as? String
    case "WebFetch":
        return input?["url"] as? String
    case "WebSearch":
        return input?["query"] as? String
    case "Task":
        let agentType = input?["subagent_type"] as? String ?? "agent"
        let description = input?["description"] as? String ?? ""
        return "\(agentType): \(description)"
    case "Skill":
        let skill = input?["skill"] as? String ?? ""
        let args = input?["args"] as? String
        if let args = args, !args.isEmpty {
            return "\(skill):\(args)"
        }
        return skill.nilIfEmpty
    case "TodoWrite":
        guard let todos = input?["todos"] as? [[String: Any]] else { return nil }
        if let data = try? JSONSerialization.data(withJSONObject: todos),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return nil
    case "TeamCreate":
        return input?["team_name"] as? String
    case "TeamDelete":
        return input?["team_name"] as? String
    case "SendMessage":
        let target = input?["target"] as? String ?? ""
        let msgType = input?["type"] as? String ?? "message"
        return "\(msgType) → \(target)"
    default:
        return nil
    }
}
