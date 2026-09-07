import Foundation

@main
struct CodexResumeGuardTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for kind in ["turn", "review", "shell"] {
            for mode in ["known-active", "resumed-active", "during-resume", "during-auth", "closed", "normal"] {
                try Data(mode.utf8).write(to: root.appendingPathComponent("mode"))
                try Data().write(to: root.appendingPathComponent("calls"))
                let queue = DispatchQueue(label: "afto.resume.fixture")
                let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 2)
                if mode == "known-active" {
                    let response = CodexTerminalRequest<[String: Any]>()
                    client.request("fixture/activate") { response.finish($0) }
                    _ = try response.wait().get()
                    precondition(client.isThreadActive(threadId: "thread"))
                    let rejected = CodexTerminalRequest<[String: Any]>()
                    var sent = false
                    client.request(
                        kind == "shell" ? "thread/shellCommand" : kind == "review" ? "review/start" : "turn/start",
                        params: ["threadId": "thread"], replyOn: queue, onSent: { sent = true }
                    ) { rejected.finish($0) }
                    if case .success = rejected.wait() { preconditionFailure("active start reached wire") }
                    precondition(queue.sync { !sent })
                }
                let runner = CodexRunner(
                    sessionId: kind + "-" + mode, hasStartedBefore: true, model: nil, effort: nil, permissionMode: nil,
                    threadId: "thread", reviewTarget: kind == "review" ? ["type": "uncommittedChanges"] : nil,
                    shellCommand: kind == "shell" ? "printf fixture" : nil, codex: client, queue: queue)
                let finished = DispatchSemaphore(value: 0)
                runner.onFinish = { finished.signal() }
                queue.async { runner.spawn(path: root.path, prompt: "fixture") }
                precondition(finished.wait(timeout: .now() + 4) == .success, kind + mode)
                queue.sync { runner.abort() }
                let journal = try String(contentsOf: CodexJournal.url(sessionId: kind + "-" + mode), encoding: .utf8)
                precondition(!journal.contains("FOREIGN CONTENT"), kind + mode)
                let calls = try String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8)
                    .split(separator: "\n").map {
                        try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
                    }
                let methods = calls.compactMap { $0["method"] as? String }
                precondition(!methods.contains("turn/interrupt"), kind + mode)
                if mode == "normal" {
                    precondition(journal.contains("OWN CONTENT"), kind)
                } else {
                    precondition(
                        !methods.contains { ["turn/start", "review/start", "thread/shellCommand"].contains($0) },
                        kind + mode)
                    precondition(journal.contains("\"type\":\"error\""), kind + mode)
                    if mode == "known-active" { precondition(!methods.contains("thread/resume")) }
                    if ["known-active", "during-resume", "during-auth"].contains(mode) {
                        precondition(client.isThreadActive(threadId: "thread"), kind + mode)
                    }
                }
                let stopped = DispatchSemaphore(value: 0)
                client.observe(id: "stop", on: queue, message: { _ in }, disconnected: { _ in stopped.signal() })
                client.stop()
                precondition(stopped.wait(timeout: .now() + 3) == .success)
            }
        }
        print(
            "Codex imported resume guards: 18 real runner cases reject active snapshots and preflight races without adoption or interruption; own events preserved"
        )
    }
}
