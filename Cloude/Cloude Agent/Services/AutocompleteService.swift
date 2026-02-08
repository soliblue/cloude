import Foundation

@MainActor
class AutocompleteService {
    private var currentProcess: Process?

    private var claudePath: String {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.npm-global/bin/claude"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "claude"
    }

    func suggest(context: [String], workingDirectory: String?, completion: @escaping ([String]) -> Void) {
        cancel()

        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = context.enumerated().map { i, msg in
                (i % 2 == 0 ? "User: " : "Assistant: ") + msg
            }.joined(separator: "\n")
        }

        let prompt = """
        Given this conversation:
        \(contextBlock)

        Suggest exactly 1 short follow-up message the user might send next. It should be 2-6 words, natural and actionable. Output ONLY a JSON array of 1 string, nothing else. Example: ["Push to git"]
        """

        let process = Process()
        let outputPipe = Pipe()

        let command = "\(claudePath) --model haiku -p \(shellEscape(prompt)) --max-turns 1 --output-format text"

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        process.environment = env

        currentProcess = process

        let timeoutWork = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                if self?.currentProcess === process && process.isRunning {
                    process.terminate()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutWork)

        process.terminationHandler = { [weak self] _ in
            timeoutWork.cancel()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                Task { @MainActor in self?.currentProcess = nil }
                return
            }

            var jsonString = output
            if let start = jsonString.firstIndex(of: "["), let end = jsonString.lastIndex(of: "]") {
                jsonString = String(jsonString[start...end])
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let suggestions = try? JSONDecoder().decode([String].self, from: jsonData),
                  !suggestions.isEmpty else {
                Task { @MainActor in self?.currentProcess = nil }
                return
            }

            let filtered = Array(suggestions.prefix(1).filter { !$0.isEmpty })
            Task { @MainActor in
                guard self?.currentProcess === process else { return }
                self?.currentProcess = nil
                if !filtered.isEmpty { completion(filtered) }
            }
        }

        do {
            try process.run()
        } catch {
            Log.error("Suggestions failed to start: \(error)")
            currentProcess = nil
        }
    }

    func suggestName(text: String, context: [String], completion: @escaping (String, String?) -> Void) {
        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = "\nConversation so far:\n" + context.map { "- \($0.prefix(300))" }.joined(separator: "\n") + "\n"
        }

        let prompt = """
        You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.

        \(contextBlock)
        Latest user message: "\(text)"

        Suggest a short conversation name (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

        Also suggest an SF Symbol icon that fits the topic.

        Respond with ONLY a JSON object like: {"name": "Short Name", "symbol": "star.fill"}
        The symbol must be a valid SF Symbol name. Pick something specific and creative, not generic.
        """

        let process = Process()
        let outputPipe = Pipe()

        let command = "\(claudePath) --model sonnet -p \(shellEscape(prompt)) --max-turns 1 --output-format text"

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        process.environment = env

        let timeoutWork = DispatchWorkItem {
            Task { @MainActor in
                if process.isRunning { process.terminate() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWork)

        process.terminationHandler = { _ in
            timeoutWork.cancel()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return }

            var jsonString = output
            if let start = jsonString.firstIndex(of: "{"), let end = jsonString.lastIndex(of: "}") {
                jsonString = String(jsonString[start...end])
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let name = json["name"] as? String, !name.isEmpty else { return }

            let symbol = json["symbol"] as? String

            Task { @MainActor in
                completion(name, symbol)
            }
        }

        do {
            try process.run()
        } catch {
            Log.error("Name suggestion failed to start: \(error)")
        }
    }

    func cancel() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }

    private func shellEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
