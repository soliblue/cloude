import Foundation
import KokoroSwift
import MLXUtilsLibrary
import MLX

struct AssistantMessage {
    let id: String
    let timestamp: String
    let text: String
}

struct SessionLocator {
    static func projectKey(from path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }

    static func locateSessionFile(prefix: String, cwd: String) throws -> URL {
        let fm = FileManager.default
        let base = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(projectKey(from: cwd))

        let entries = try fm.contentsOfDirectory(atPath: base.path)
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".jsonl") }

        guard entries.count == 1 else {
            let found = entries.sorted().joined(separator: "\n")
            throw NSError(domain: "KokoroReplay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected exactly 1 session for prefix '\(prefix)', found \(entries.count).\n\(found)"])
        }

        return base.appendingPathComponent(entries[0])
    }
}

struct HistoryReader {
    static func assistantMessages(from file: URL) throws -> [AssistantMessage] {
        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.split(separator: "\n")
        var result: [AssistantMessage] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = root["type"] as? String,
                  type == "assistant",
                  let timestamp = root["timestamp"] as? String,
                  let message = root["message"] as? [String: Any],
                  let id = message["id"] as? String,
                  let contentItems = message["content"] as? [[String: Any]] else {
                continue
            }

            let text = contentItems.compactMap { item -> String? in
                guard let itemType = item["type"] as? String, itemType == "text" else { return nil }
                return item["text"] as? String
            }.joined()

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(AssistantMessage(id: id, timestamp: timestamp, text: text))
            }
        }

        return result
    }
}

struct MarkdownStripper {
    static func strip(_ text: String) -> String {
        var result = text
        result = replacing(result, pattern: "```[\\s\\S]*?```", with: "")
        result = replacing(result, pattern: "`[^`]+`", with: "")
        result = replacing(result, pattern: "\\*\\*([^*]+)\\*\\*", with: "$1")
        result = replacing(result, pattern: "\\*([^*]+)\\*", with: "$1")
        result = replacing(result, pattern: "#{1,6}\\s+", with: "")
        result = replacing(result, pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1")
        result = replacing(result, pattern: "^[\\s]*[-*+]\\s+", with: "")
        result = replacing(result, pattern: "(?m)^>\\s+", with: "")
        result = replacing(result, pattern: "\\|[^\\n]+\\|", with: "")
        result = replacing(result, pattern: "---+", with: "")
        result = replacing(result, pattern: "\n{3,}", with: "\n\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacing(_ text: String, pattern: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

struct Args {
    let sessionPrefix: String
    let voice: String
    let limit: Int?
    let projectPath: String

    static func parse() throws -> Args {
        var sessionPrefix: String?
        var voice = "am_adam"
        var limit: Int?
        var projectPath = FileManager.default.currentDirectoryPath

        var i = 1
        let argv = CommandLine.arguments
        while i < argv.count {
            switch argv[i] {
            case "--session-prefix":
                i += 1; guard i < argv.count else { throw usage("Missing value for --session-prefix") }
                sessionPrefix = argv[i]
            case "--voice":
                i += 1; guard i < argv.count else { throw usage("Missing value for --voice") }
                voice = argv[i]
            case "--limit":
                i += 1; guard i < argv.count, let n = Int(argv[i]) else { throw usage("Invalid value for --limit") }
                limit = n
            case "--project-path":
                i += 1; guard i < argv.count else { throw usage("Missing value for --project-path") }
                projectPath = argv[i]
            default:
                throw usage("Unknown arg: \(argv[i])")
            }
            i += 1
        }

        guard let sessionPrefix else {
            throw usage("Missing --session-prefix")
        }

        return Args(sessionPrefix: sessionPrefix, voice: voice, limit: limit, projectPath: projectPath)
    }

    private static func usage(_ message: String) -> NSError {
        NSError(domain: "KokoroReplay", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(message)\nUsage: swift run KokoroReplay --session-prefix <8+ chars> [--voice am_adam] [--limit N] [--project-path /path/to/project]"])
    }
}

@main
struct KokoroReplayMain {
    static func main() {
        do {
            let args = try Args.parse()
            let sessionFile = try SessionLocator.locateSessionFile(prefix: args.sessionPrefix, cwd: args.projectPath)
            let all = try HistoryReader.assistantMessages(from: sessionFile)
            let messages = args.limit.map { Array(all.prefix($0)) } ?? all

            guard !messages.isEmpty else {
                print("No assistant messages with text found in \(sessionFile.path)")
                return
            }

            let modelDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Cloude/KokoroTTS")
            let modelPath = modelDir.appendingPathComponent("kokoro-v1_0.safetensors")
            let voicesPath = modelDir.appendingPathComponent("voices.npz")

            guard let voices = NpyzReader.read(fileFromPath: voicesPath),
                  let voice = voices[args.voice + ".npy"] else {
                throw NSError(domain: "KokoroReplay", code: 3, userInfo: [NSLocalizedDescriptionKey: "Voice '\(args.voice)' not found in \(voicesPath.path)"])
            }

            let language: Language = args.voice.first == "a" ? .enUS : .enGB
            let tts = KokoroTTS(modelPath: modelPath)

            var failures = 0
            var success = 0

            print("Session: \(sessionFile.lastPathComponent)")
            print("Messages to test: \(messages.count)")
            print("Voice: \(args.voice) | maxTokenCount: \(KokoroTTS.Constants.maxTokenCount)")
            print("-")

            for (idx, msg) in messages.enumerated() {
                let stripped = MarkdownStripper.strip(msg.text)
                guard !stripped.isEmpty else { continue }

                let started = Date()
                do {
                    let (audio, tokens) = try tts.generateAudio(voice: voice, language: language, text: stripped)
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    success += 1
                    print("[OK  ] #\(idx + 1) id=\(msg.id.prefix(8)) chars=\(stripped.count) samples=\(audio.count) tokens=\(tokens?.count ?? -1) t=\(ms)ms")
                } catch {
                    failures += 1
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    print("[FAIL] #\(idx + 1) id=\(msg.id.prefix(8)) chars=\(stripped.count) t=\(ms)ms err=\(error)")
                }
            }

            print("-")
            print("Summary: ok=\(success) fail=\(failures)")
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
