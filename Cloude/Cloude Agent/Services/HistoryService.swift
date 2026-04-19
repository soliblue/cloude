import Foundation
import CloudeShared

enum HistoryError: Error {
    case fileNotFound(String)
    case readFailed(String)
}

struct HistoryService {
    static func getHistory(sessionId: String, workingDirectory: String) -> Result<[HistoryMessage], HistoryError> {
        let projectPath = workingDirectory.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")

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
            var assistantMessages: [String: (timestamp: Date, model: String?, items: [ContentItem])] = [:]
            var toolResults: [String: String] = [:]

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
                        } else if let contentArray = messageObj["content"] as? [[String: Any]] {
                            for item in contentArray {
                                if let itemType = item["type"] as? String,
                                   itemType == "tool_result",
                                   let toolUseId = item["tool_use_id"] as? String {
                                    var output = ""
                                    if let text = item["content"] as? String {
                                        output = text
                                    } else if let contentParts = item["content"] as? [[String: Any]] {
                                        output = contentParts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                                    }
                                    if !output.isEmpty {
                                        toolResults[toolUseId] = String(output.prefix(5000))
                                    }
                                }
                            }
                        }
                    }
                } else if type == "assistant" {
                    guard let messageObj = json["message"] as? [String: Any],
                          let contentArray = messageObj["content"] as? [[String: Any]] else {
                        continue
                    }

                    let messageId = messageObj["id"] as? String ?? uuid
                    let model = messageObj["model"] as? String

                    for item in contentArray {
                        guard let itemType = item["type"] as? String else { continue }

                        let contentItem: ContentItem
                        if itemType == "text", let text = item["text"] as? String {
                            contentItem = ContentItem(type: "text", text: text, toolName: nil, toolId: nil, toolInput: nil, editInfo: nil)
                        } else if itemType == "tool_use",
                                  let name = item["name"] as? String,
                                  let toolId = item["id"] as? String {
                            let inputDict = item["input"] as? [String: Any]
                            let inputStr = ToolInputExtractor.extract(name: name, input: inputDict)
                            let editInfo = name == "Edit" ? ToolInputExtractor.extractEditInfo(input: inputDict) : nil
                            contentItem = ContentItem(type: "tool_use", text: nil, toolName: name, toolId: toolId, toolInput: inputStr, editInfo: editInfo)
                        } else {
                            continue
                        }

                        if var existing = assistantMessages[messageId] {
                            existing.items.append(contentItem)
                            assistantMessages[messageId] = existing
                        } else {
                            assistantMessages[messageId] = (timestamp, model, [contentItem])
                        }
                    }
                }
            }

            let messages = Self.buildAndMergeMessages(
                userMessages: userMessages,
                assistantMessages: assistantMessages,
                toolResults: toolResults
            )
            return .success(messages)
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }
}
