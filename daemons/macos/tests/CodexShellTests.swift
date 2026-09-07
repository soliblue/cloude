import Darwin
import Foundation

@main struct CodexShellTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let queue = DispatchQueue(label: "afto.shell.fixture")
        for mode in ["early", "late", "cancel-before-id", "journal-failure", "apikey"] {
            try Data(mode.utf8).write(to: root.appendingPathComponent("mode"))
            let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 3)
            let runner = CodexRunner(
                sessionId: mode, hasStartedBefore: false, model: "fixture-model", effort: nil,
                permissionMode: nil, threadId: nil, shellCommand: "printf 'hello shell'", codex: client, queue: queue)
            let finished = DispatchSemaphore(value: 0)
            runner.onFinish = { finished.signal() }
            try? FileManager.default.removeItem(at: root.appendingPathComponent("acknowledged"))
            queue.async { runner.spawn(path: root.path, prompt: "Run command") }
            var previousLimit = rlimit()
            if ["cancel-before-id", "journal-failure"].contains(mode) {
                let deadline = Date().addingTimeInterval(4)
                while Date() < deadline
                    && !FileManager.default.fileExists(atPath: root.appendingPathComponent("acknowledged").path)
                {
                    Thread.sleep(forTimeInterval: 0.005)
                }
                precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("acknowledged").path))
                if mode == "journal-failure" {
                    precondition(getrlimit(RLIMIT_FSIZE, &previousLimit) == 0)
                    var limit = previousLimit
                    limit.rlim_cur = 0
                    signal(SIGXFSZ, SIG_IGN)
                    precondition(setrlimit(RLIMIT_FSIZE, &limit) == 0)
                } else {
                    queue.sync { runner.abort() }
                }
            }
            let completed = finished.wait(timeout: .now() + 5)
            if mode == "journal-failure" {
                precondition(setrlimit(RLIMIT_FSIZE, &previousLimit) == 0)
                let deadline = Date().addingTimeInterval(2)
                while Date() < deadline
                    && !((try? String(contentsOf: root.appendingPathComponent(mode + ".jsonl"), encoding: .utf8)) ?? "")
                        .contains("turn/interrupt")
                {
                    Thread.sleep(forTimeInterval: 0.005)
                }
            }
            precondition(completed == .success, mode)
            let requests = try String(contentsOf: root.appendingPathComponent(mode + ".jsonl"), encoding: .utf8)
                .split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
            precondition(
                !requests.contains {
                    ["turn/start", "review/start", "account/rateLimits/read"].contains($0["method"] as? String ?? "")
                })
            precondition(requests.contains { $0["method"] as? String == "thread/shellCommand" } == (mode != "apikey"))
            let events = try String(contentsOf: CodexJournal.url(sessionId: mode), encoding: .utf8)
                .split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
            if mode == "journal-failure" {
                precondition(runner.hasExited)
                precondition(events.count == 1 && events.first?["type"] as? String == "session")
                precondition(requests.contains { $0["method"] as? String == "turn/interrupt" })
            } else {
                precondition(events.last?["type"] as? String == "exit")
            }
            precondition(!events.contains { ($0["event"] as? [String: Any])?["subtype"] as? String == "init" })
            if mode == "cancel-before-id" {
                precondition(requests.contains { $0["method"] as? String == "turn/interrupt" })
                precondition(events.contains { $0["type"] as? String == "aborted" })
            }
            if ["early", "late"].contains(mode) {
                precondition(
                    events.contains { (($0["toolOutput"] as? String) ?? "").contains("hello shell") }
                        || String(describing: events).contains("hello shell"))
            }
        }
        for command: Any in ["", " \n", "x\0y", String(repeating: "🙂", count: 8193), 42, NSNull()] {
            precondition(!CodexShellCommand.valid(command))
        }
        precondition(CodexShellCommand.valid("  printf 'hello' | cat\n"))
        for extra: [String: Any] in [
            ["provider": "claude"], ["reviewTarget": ["type": "uncommittedChanges"]],
            ["images": [["data": "x", "mediaType": "image/png"]]], ["skills": [["name": "x", "path": "/x"]]],
            ["shellCommand": " "],
        ] {
            var body: [String: Any] = ["provider": "codex", "path": root.path, "prompt": "Run", "shellCommand": "pwd"]
            body.merge(extra) { _, value in value }
            let head = HTTPRequest.parseHead(Data("POST /sessions/invalid/chat HTTP/1.1\r\n\r\n".utf8))!
            let request = HTTPRequest(head: head, body: try JSONSerialization.data(withJSONObject: body))
            precondition(ChatHandler.start(request, params: ["id": "invalid"]).status == 400)
        }
        print(
            "Native shell: no inference or quota calls, early/late acknowledgements, cancellation before turn ID, subscription identity, exact command payload, streaming journal, real file-size-limit write failure and invalid mixed input passed"
        )
    }
}
