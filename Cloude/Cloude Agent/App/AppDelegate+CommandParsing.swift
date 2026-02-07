import SwiftUI
import Network
import CloudeShared

fileprivate struct QuestionJSON: Codable {
    let q: String
    let options: [AnyCodable]
    let multi: Bool?

    struct AnyCodable: Codable {
        let value: Any

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                value = str
            } else if let dict = try? container.decode([String: String].self) {
                value = dict
            } else {
                value = ""
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let str = value as? String {
                try container.encode(str)
            } else if let dict = value as? [String: String] {
                try container.encode(dict)
            }
        }
    }
}

extension AppDelegate {
    func handleCloudeCommand(_ command: String, conversationId: String?) {
        let parts = command.dropFirst(7).split(separator: " ", maxSplits: 1).map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "rename":
            guard let convId = conversationId, parts.count >= 2 else { return }
            let name = parts[1]
            server.broadcast(.renameConversation(name: name, conversationId: convId))
            Log.info("Renamed conversation \(convId.prefix(8)) to '\(name)'")

        case "symbol":
            guard let convId = conversationId else { return }
            let symbol = parts.count >= 2 ? parts[1] : nil
            server.broadcast(.setConversationSymbol(symbol: symbol, conversationId: convId))
            Log.info("Set symbol for \(convId.prefix(8)) to '\(symbol ?? "nil")'")

        case "memory":
            guard parts.count >= 2 else { return }
            let memoryArgs = parts[1].split(separator: " ", maxSplits: 2).map(String.init)
            guard memoryArgs.count >= 3 else {
                Log.info("Memory command requires: cloude memory <local|project> <section> <text>")
                return
            }

            let targetStr = memoryArgs[0].lowercased()
            let section = memoryArgs[1]
            let text = memoryArgs[2]

            let target: MemoryService.MemoryTarget
            switch targetStr {
            case "local": target = .local
            case "project": target = .project
            default:
                Log.info("Unknown memory target: \(targetStr). Use 'local' or 'project'")
                return
            }

            let success = MemoryService.addMemory(target: target, section: section, text: text)
            if success {
                server.broadcast(.memoryAdded(target: targetStr, section: section, text: text, conversationId: conversationId))
            }

        case "skip":
            Log.info("Heartbeat skipped for \(conversationId?.prefix(8) ?? "nil")")
            server.broadcast(.heartbeatSkipped(conversationId: conversationId))

        case "delete":
            guard let convId = conversationId else { return }
            server.broadcast(.deleteConversation(conversationId: convId))
            Log.info("Delete conversation \(convId.prefix(8))")

        case "notify":
            guard parts.count >= 2 else { return }
            let body = parts[1]
            server.broadcast(.notify(title: nil, body: body, conversationId: conversationId))
            Log.info("Notify: \(body.prefix(50))")

        case "clipboard":
            guard parts.count >= 2 else { return }
            let text = parts[1]
            server.broadcast(.clipboard(text: text))
            Log.info("Clipboard: \(text.prefix(50))")

        case "open":
            guard parts.count >= 2 else { return }
            let url = parts[1]
            server.broadcast(.openURL(url: url))
            Log.info("Open URL: \(url)")

        case "haptic":
            let style = parts.count >= 2 ? parts[1] : "medium"
            server.broadcast(.haptic(style: style))
            Log.info("Haptic: \(style)")

        case "speak":
            guard parts.count >= 2 else { return }
            let text = parts[1]
            server.broadcast(.speak(text: text))
            Log.info("Speak: \(text.prefix(50))")

        case "switch":
            guard parts.count >= 2 else { return }
            let targetId = parts[1]
            server.broadcast(.switchConversation(conversationId: targetId))
            Log.info("Switch to conversation: \(targetId.prefix(8))")

        case "ask":
            guard parts.count >= 2 else { return }
            let questions = parseAskCommand(parts[1])
            guard !questions.isEmpty else {
                Log.info("cloude ask: no valid questions parsed")
                return
            }
            server.broadcast(.question(questions: questions, conversationId: conversationId))
            Log.info("Ask: \(questions.count) question(s)")

        case "screenshot":
            server.broadcast(.screenshot(conversationId: conversationId))
            Log.info("Screenshot requested for \(conversationId?.prefix(8) ?? "nil")")

        default:
            Log.info("Unknown cloude command: \(action)")
        }
    }

    func parseAskCommand(_ args: String) -> [Question] {
        if args.hasPrefix("--questions ") {
            let jsonStr = String(args.dropFirst(12))
            return parseQuestionsJSON(jsonStr)
        }

        if args.hasPrefix("--q ") {
            return parseSimpleQuestion(args)
        }

        return parseQuestionsJSON(args)
    }

    func parseQuestionsJSON(_ jsonStr: String) -> [Question] {
        var cleaned = jsonStr.trimmingCharacters(in: .whitespaces)
        if (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) ||
           (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard let data = cleaned.data(using: .utf8) else { return [] }

        do {
            let decoded = try JSONDecoder().decode([QuestionJSON].self, from: data)
            return decoded.map { q in
                let options = q.options.map { opt -> QuestionOption in
                    if let dict = opt.value as? [String: String] {
                        return QuestionOption(
                            label: dict["label"] ?? "",
                            description: dict["desc"] ?? dict["description"]
                        )
                    } else if let str = opt.value as? String {
                        return QuestionOption(label: str)
                    }
                    return QuestionOption(label: String(describing: opt.value))
                }
                return Question(text: q.q, options: options, multiSelect: q.multi ?? false)
            }
        } catch {
            Log.error("Failed to parse questions JSON: \(error)")
            return []
        }
    }

    func parseSimpleQuestion(_ args: String) -> [Question] {
        var questionText = ""
        var optionsStr = ""
        var multi = false

        let parts = args.components(separatedBy: " --")
        for part in parts {
            let trimmed = part.hasPrefix("-") ? String(part.drop(while: { $0 == "-" })) : part
            if trimmed.hasPrefix("q ") {
                questionText = String(trimmed.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed.hasPrefix("options ") {
                optionsStr = String(trimmed.dropFirst(8)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed == "multi" {
                multi = true
            }
        }

        guard !questionText.isEmpty, !optionsStr.isEmpty else { return [] }

        let options = optionsStr.split(separator: ",").map { optStr -> QuestionOption in
            let parts = optStr.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                return QuestionOption(label: String(parts[0]), description: String(parts[1]))
            }
            return QuestionOption(label: String(optStr))
        }

        return [Question(text: questionText, options: options, multiSelect: multi)]
    }
}
