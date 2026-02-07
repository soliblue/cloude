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

    func complete(text: String, context: [String], workingDirectory: String?, completion: @escaping (String?) -> Void) {
        cancel()

        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = "Recent conversation:\n" + context.enumerated().map { i, msg in
                (i % 2 == 0 ? "User: " : "Assistant: ") + msg
            }.joined(separator: "\n") + "\n\n"
        }

        let prompt = """
        \(contextBlock)The user is typing a message and has written: "\(text)"

        Complete their message naturally. Output ONLY the remaining text that would come after what they've already typed. Do not repeat what they typed. Keep it concise — just finish their thought in a few words. If you can't think of a good completion, output nothing.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutWork)

        process.terminationHandler = { [weak self] _ in
            timeoutWork.cancel()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                guard self?.currentProcess === process else { return }
                self?.currentProcess = nil
                completion(output?.isEmpty == true ? nil : output)
            }
        }

        do {
            try process.run()
        } catch {
            Log.error("Autocomplete failed to start: \(error)")
            currentProcess = nil
            completion(nil)
        }
    }

    func suggestName(text: String, context: [String], completion: @escaping (String, String?) -> Void) {
        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = "\nRecent messages:\n" + context.suffix(4).map { "- \($0.prefix(200))" }.joined(separator: "\n") + "\n"
        }

        let prompt = """
        Given this conversation, suggest a short conversation name (1-2 words, catchy/memorable) and an SF Symbol icon name that fits.
        \(contextBlock)
        Latest message: "\(text)"

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
