import Foundation
import CloudeShared

struct HistoryService {

    static func getHistory(sessionId: String, workingDirectory: String) -> Result<[HistoryMessage], String> {
        let projectPath = workingDirectory.replacingOccurrences(of: "/", with: "-")
        let trimmedPath = projectPath.hasPrefix("-") ? String(projectPath.dropFirst()) : projectPath

        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let sessionFile = claudeProjectsDir
            .appendingPathComponent(trimmedPath)
            .appendingPathComponent("\(sessionId).jsonl")

        guard FileManager.default.fileExists(atPath: sessionFile.path) else {
            return .failure("Session file not found: \(sessionFile.path)")
        }

        do {
            let content = try String(contentsOf: sessionFile, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            var messages: [HistoryMessage] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for line in lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let timestampStr = json["timestamp"] as? String else {
                    continue
                }

                let timestamp = dateFormatter.date(from: timestampStr) ?? Date()

                if type == "user" {
                    if let messageObj = json["message"] as? [String: Any],
                       let content = messageObj["content"] as? String {
                        messages.append(HistoryMessage(isUser: true, text: content, timestamp: timestamp))
                    }
                } else if type == "assistant" {
                    if let messageObj = json["message"] as? [String: Any],
                       let contentArray = messageObj["content"] as? [[String: Any]] {
                        var textParts: [String] = []
                        for item in contentArray {
                            if let itemType = item["type"] as? String, itemType == "text",
                               let text = item["text"] as? String {
                                textParts.append(text)
                            }
                        }
                        if !textParts.isEmpty {
                            messages.append(HistoryMessage(isUser: false, text: textParts.joined(separator: "\n"), timestamp: timestamp))
                        }
                    }
                }
            }

            return .success(messages)
        } catch {
            return .failure("Failed to read session file: \(error.localizedDescription)")
        }
    }
}
