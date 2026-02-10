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
            var assistantMessages: [String: (timestamp: Date, model: String?, items: [ContentItem])] = [:]

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

                    let messageId = messageObj["id"] as? String ?? uuid
                    let model = messageObj["model"] as? String

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

                        if var existing = assistantMessages[messageId] {
                            existing.items.append(contentItem)
                            assistantMessages[messageId] = existing
                        } else {
                            assistantMessages[messageId] = (timestamp, model, [contentItem])
                        }
                    }
                }
            }

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
                        toolCalls.append(StoredToolCall(name: name, input: item.toolInput, toolId: toolId, textPosition: position))
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
                        StoredToolCall(name: tool.name, input: tool.input, toolId: tool.toolId, parentToolId: tool.parentToolId, textPosition: (tool.textPosition ?? 0) + textOffset)
                    }
                    merged[lastIdx] = HistoryMessage(isUser: false, text: combinedText, timestamp: prev.timestamp, toolCalls: prev.toolCalls + adjustedTools, serverUUID: prev.serverUUID ?? msg.serverUUID, model: prev.model ?? msg.model)
                } else {
                    merged.append(msg)
                }
            }

            return .success(merged)
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }

    static func listSessions(workingDirectory: String) -> [RemoteSession] {
        let projectPath = workingDirectory.replacingOccurrences(of: "/", with: "-")
        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(projectPath)

        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: claudeProjectsDir, includingPropertiesForKeys: [.contentModificationDateKey])
            var sessions: [RemoteSession] = []

            for file in files where file.pathExtension == "jsonl" {
                let sessionId = file.deletingPathExtension().lastPathComponent
                guard UUID(uuidString: sessionId) != nil else { continue }

                let attributes = try file.resourceValues(forKeys: [.contentModificationDateKey])
                let lastModified = attributes.contentModificationDate ?? Date.distantPast

                let content = try String(contentsOf: file, encoding: .utf8)
                let messageCount = content.components(separatedBy: .newlines)
                    .filter { line in
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String else { return false }
                        return type == "user" || type == "assistant"
                    }.count

                sessions.append(RemoteSession(
                    sessionId: sessionId,
                    workingDirectory: workingDirectory,
                    lastModified: lastModified,
                    messageCount: messageCount
                ))
            }

            return sessions.sorted { $0.lastModified > $1.lastModified }
        } catch {
            return []
        }
    }

    private static func extractToolInput(name: String, input: [String: Any]?) -> String? {
        ToolInputExtractor.extract(name: name, input: input)
    }
}
