import Foundation
import Combine

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

            if type == "result" {
                if let sessionId = json["session_id"] as? String {
                    events.send(.sessionId(sessionId))
                    onSessionId?(sessionId)
                }
                if let durationMs = json["duration_ms"] as? Int,
                   let costUsd = json["total_cost_usd"] as? Double {
                    events.send(.runStats(durationMs: durationMs, costUsd: costUsd))
                    onRunStats?(durationMs, costUsd)
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

        if let imagePath = tempImagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
            tempImagePath = nil
        }
    }

    private func extractToolInput(name: String, input: [String: Any]?) -> String? {
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
        default:
            return nil
        }
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
