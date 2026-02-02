import Foundation
import CloudeShared

enum HistoryError: Error {
    case fileNotFound(String)
    case readFailed(String)
}

struct HistoryService {

    private struct ContentItem {
        let type: String
        let text: String?
        let toolName: String?
        let toolId: String?
        let toolInput: String?
    }

    static func getHistory(sessionId: String, workingDirectory: String) -> Result<[HistoryMessage], HistoryError> {
        let projectPath = workingDirectory.replacingOccurrences(of: "/", with: "-")

        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let sessionFile = claudeProjectsDir
            .appendingPathComponent(projectPath)
            .appendingPathComponent("\(sessionId).jsonl")

        guard FileManager.default.fileExists(atPath: sessionFile.path) else {
            return .failure(.fileNotFound(sessionFile.path))
        }

        do {
            let content = try String(contentsOf: sessionFile, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var userMessages: [(uuid: String, timestamp: Date, text: String)] = []
            var assistantMessages: [String: (timestamp: Date, items: [ContentItem])] = [:]

            for line in lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let timestampStr = json["timestamp"] as? String,
                      let uuid = json["uuid"] as? String else {
                    continue
                }

                let timestamp = dateFormatter.date(from: timestampStr) ?? Date()

                if type == "user" {
                    if let messageObj = json["message"] as? [String: Any] {
                        if let content = messageObj["content"] as? String {
                            userMessages.append((uuid, timestamp, content))
                        }
                    }
                } else if type == "assistant" {
                    guard let messageObj = json["message"] as? [String: Any],
                          let contentArray = messageObj["content"] as? [[String: Any]] else {
                        continue
                    }

                    for item in contentArray {
                        guard let itemType = item["type"] as? String else { continue }

                        let contentItem: ContentItem
                        if itemType == "text", let text = item["text"] as? String {
                            contentItem = ContentItem(type: "text", text: text, toolName: nil, toolId: nil, toolInput: nil)
                        } else if itemType == "tool_use",
                                  let name = item["name"] as? String,
                                  let toolId = item["id"] as? String {
                            let inputDict = item["input"] as? [String: Any]
                            let inputStr = extractToolInput(name: name, input: inputDict)
                            contentItem = ContentItem(type: "tool_use", text: nil, toolName: name, toolId: toolId, toolInput: inputStr)
                        } else {
                            continue
                        }

                        if var existing = assistantMessages[uuid] {
                            existing.items.append(contentItem)
                            assistantMessages[uuid] = existing
                        } else {
                            assistantMessages[uuid] = (timestamp, [contentItem])
                        }
                    }
                }
            }

            var allMessages: [(uuid: String, timestamp: Date, message: HistoryMessage)] = []

            for user in userMessages {
                allMessages.append((user.uuid, user.timestamp, HistoryMessage(isUser: true, text: user.text, timestamp: user.timestamp)))
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
                        toolCalls.append(StoredToolCall(name: name, input: item.toolInput, toolId: toolId, textPosition: position))
                    }
                }

                if !accumulatedText.isEmpty || !toolCalls.isEmpty {
                    allMessages.append((uuid, data.timestamp, HistoryMessage(isUser: false, text: accumulatedText, timestamp: data.timestamp, toolCalls: toolCalls)))
                }
            }

            let sorted = allMessages.sorted { $0.timestamp < $1.timestamp }
            return .success(sorted.map { $0.message })
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }

    private static func extractToolInput(name: String, input: [String: Any]?) -> String? {
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
}
