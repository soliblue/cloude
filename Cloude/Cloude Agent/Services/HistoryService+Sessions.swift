import Foundation
import CloudeShared

extension HistoryService {
    struct ContentItem {
        let type: String
        let text: String?
        let toolName: String?
        let toolId: String?
        let toolInput: String?
        let editInfo: EditInfo?
    }

    static func buildAndMergeMessages(
        userMessages: [(uuid: String, timestamp: Date, text: String)],
        assistantMessages: [String: (timestamp: Date, model: String?, items: [ContentItem])],
        toolResults: [String: String]
    ) -> [HistoryMessage] {
        var allMessages: [(uuid: String, timestamp: Date, message: HistoryMessage)] = []

        for user in userMessages {
            allMessages.append((user.uuid, user.timestamp, HistoryMessage(isUser: true, text: user.text, timestamp: user.timestamp, serverUUID: user.uuid)))
        }

        for (uuid, data) in assistantMessages {
            var accumulatedText = ""
            var toolCalls: [StoredToolCall] = []

            for item in data.items {
                if item.type == "text", let text = item.text {
                    accumulatedText += text
                } else if item.type == "tool_use",
                          let name = item.toolName,
                          let toolId = item.toolId {
                    let position = accumulatedText.count
                    toolCalls.append(StoredToolCall(name: name, input: item.toolInput, toolId: toolId, textPosition: position, editInfo: item.editInfo, resultContent: toolResults[toolId]))
                }
            }

            if !accumulatedText.isEmpty || !toolCalls.isEmpty {
                allMessages.append((uuid, data.timestamp, HistoryMessage(isUser: false, text: accumulatedText, timestamp: data.timestamp, toolCalls: toolCalls, serverUUID: uuid, model: data.model)))
            }
        }

        let sorted = allMessages.sorted { $0.timestamp < $1.timestamp }

        var merged: [HistoryMessage] = []
        for entry in sorted {
            let msg = entry.message
            if !msg.isUser, let lastIdx = merged.indices.last, !merged[lastIdx].isUser {
                let prev = merged[lastIdx]
                let separator = (!prev.text.isEmpty && !msg.text.isEmpty) ? "\n\n" : ""
                let combinedText = prev.text + separator + msg.text
                let textOffset = prev.text.count + separator.count
                let adjustedTools = msg.toolCalls.map { tool in
                    StoredToolCall(name: tool.name, input: tool.input, toolId: tool.toolId, parentToolId: tool.parentToolId, textPosition: (tool.textPosition ?? 0) + textOffset, editInfo: tool.editInfo, resultContent: tool.resultContent)
                }
                merged[lastIdx] = HistoryMessage(isUser: false, text: combinedText, timestamp: prev.timestamp, toolCalls: prev.toolCalls + adjustedTools, serverUUID: prev.serverUUID ?? msg.serverUUID, model: prev.model ?? msg.model)
            } else {
                merged.append(msg)
            }
        }

        return merged
    }
}
