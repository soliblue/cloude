import Foundation

enum SessionHandler {
    static func updateTitle(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"],
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let path = body["path"] as? String
        {
            let transcript = readTranscript(path: path, sessionId: sessionId)
            if transcript.isEmpty {
                return HTTPResponse.json(404, ["error": "transcript_not_found"])
            }
            let metaPrompt = """
                You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.

                Conversation:
                \(transcript)

                Suggest a short conversation title (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

                Also pick an SF Symbol name that best fits the topic. Pick something specific and creative, not generic. Prefer outline versions (e.g. "star" over "star.fill") unless only a .fill variant exists.

                Respond with ONLY a JSON object and nothing else: {"title": "Short Title", "symbol": "sf.symbol.name"}
                """
            let output = runSonnet(prompt: metaPrompt)
            let outer =
                output
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if let output,
                let parsed =
                    ((outer?["result"] as? String).flatMap(parseJSONBlock)
                        ?? parseJSONBlock(output)),
                let title = parsed["title"] as? String,
                let symbol = parsed["symbol"] as? String
            {
                return HTTPResponse.json(200, ["title": title, "symbol": symbol])
            }
            return HTTPResponse.json(500, ["error": "generation_failed"])
        }
        return HTTPResponse.json(400, ["error": "missing_params"])
    }

    private static func readTranscript(path: String, sessionId: String) -> String {
        let encoded =
            path
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".claude/projects/\(encoded)/\(sessionId).jsonl")
        if let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        {
            var lines: [String] = []
            for raw in text.split(separator: "\n") {
                if let lineData = raw.data(using: .utf8),
                    let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    let message = obj["message"] as? [String: Any],
                    let role = message["role"] as? String
                {
                    if let str = message["content"] as? String {
                        lines.append("\(role): \(str)")
                    } else if let blocks = message["content"] as? [[String: Any]] {
                        for block in blocks {
                            if let type = block["type"] as? String, type == "text",
                                let str = block["text"] as? String
                            {
                                lines.append("\(role): \(str)")
                            }
                        }
                    }
                }
            }
            return lines.joined(separator: "\n\n")
        }
        return ""
    }

    private static func runSonnet(prompt: String) -> String? {
        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        let executable = claudeExecutable()
        proc.executableURL = URL(fileURLWithPath: executable.path)
        proc.arguments =
            executable.leadingArguments + [
                "-p", "--model", "sonnet", "--output-format", "json",
            ]
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        let inherited = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in ["HOME", "USER", "SHELL", "LANG", "LC_ALL", "TMPDIR", "TERM"] {
            if let value = inherited[key] { env[key] = value }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var pathParts = (inherited["PATH"] ?? "").split(separator: ":").map(String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !pathParts.contains(extra) {
            pathParts.append(extra)
        }
        env["PATH"] = pathParts.joined(separator: ":")
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        env["NO_COLOR"] = "1"
        env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        proc.environment = env
        if (try? proc.run()) != nil {
            stdin.fileHandleForWriting.write(prompt.data(using: .utf8) ?? Data())
            try? stdin.fileHandleForWriting.close()
            proc.waitUntilExit()
            let data = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
            let errData = (try? stderr.fileHandleForReading.readToEnd()) ?? Data()
            if proc.terminationStatus != 0 {
                let errText = String(data: errData, encoding: .utf8) ?? ""
                NSLog("[SessionHandler] runSonnet exit=\(proc.terminationStatus) stderr=\(errText)")
            }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private struct Executable {
        let path: String
        let leadingArguments: [String]
    }

    private static func claudeExecutable() -> Executable {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var directories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(
            String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !directories.contains(extra) {
            directories.append(extra)
        }
        for directory in directories {
            let candidate = "\(directory)/claude"
            if fileManager.isExecutableFile(atPath: candidate) {
                return Executable(path: candidate, leadingArguments: [])
            }
        }
        return Executable(path: "/usr/bin/env", leadingArguments: ["claude"])
    }

    private static func parseJSONBlock(_ text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            return obj
        }
        if let start = trimmed.firstIndex(of: "{"),
            let end = trimmed.lastIndex(of: "}"),
            start < end
        {
            let slice = String(trimmed[start...end])
            if let data = slice.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                return obj
            }
        }
        return nil
    }
}
