import Foundation
import Combine
import CloudeShared

extension ClaudeCodeRunner {
    func processStreamLines(_ text: String) {
        lineBuffer += text
        let lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.last ?? ""

        for line in lines.dropLast() {
            if line.isEmpty { continue }
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleStreamEvent(json)
            }
        }
    }

    private func handleStreamEvent(_ json: [String: Any]) {
        let type = json["type"] as? String ?? ""

        if type == "system" {
            handleSystemEvent(json)
        }

        handleContentBlockEvent(type: type, json: json)

        let parentToolUseId = json["parent_tool_use_id"] as? String

        if type == "assistant" {
            handleAssistantMessage(json, parentToolId: parentToolUseId)
        }

        if type == "user" {
            handleUserMessage(json)
        }

        if type == "result" {
            handleResultEvent(json)
        }
    }

    private func handleSystemEvent(_ json: [String: Any]) {
        if let subtype = json["subtype"] as? String {
            if subtype == "init", let sessionId = json["session_id"] as? String {
                if activeModel == nil, let model = json["model"] as? String {
                    activeModel = model
                }
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
    }

    private func handleAssistantMessage(_ json: [String: Any], parentToolId: String?) {
        if let message = json["message"] as? [String: Any],
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
                    let inputDict = block["input"] as? [String: Any]
                    let input = ToolInputExtractor.extract(name: toolName, input: inputDict)
                    let editInfo = toolName == "Edit" ? ToolInputExtractor.extractEditInfo(input: inputDict) : nil
                    let textPosition = accumulatedOutput.count
                    events.send(.toolCall(name: toolName, input: input, toolId: toolId, parentToolId: parentToolId))
                    onToolCall?(toolName, input, toolId, parentToolId, textPosition, editInfo)
                }
            }
        }
    }

    private func handleUserMessage(_ json: [String: Any]) {
        if let message = json["message"] as? [String: Any] {
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
                        let (summary, output) = extractResultInfo(from: block)
                        events.send(.toolResult(toolId: toolUseId, summary: summary, output: output))
                        onToolResult?(toolUseId, summary, output)
                        parseTeamResult(from: block)
                    }
                }
            }
        }
    }

    private func handleResultEvent(_ json: [String: Any]) {
        if let sessionId = json["session_id"] as? String {
            events.send(.sessionId(sessionId))
            onSessionId?(sessionId)
        }
        if let durationMs = json["duration_ms"] as? Int,
           let costUsd = json["total_cost_usd"] as? Double {
            let model = json["model"] as? String ?? activeModel
            pendingRunStats = (durationMs, costUsd, model)
        }
        if let result = json["result"] as? String, accumulatedOutput.isEmpty {
            events.send(.output(result))
            onOutput?(result)
        }
    }
}
