import Foundation

@main
struct ClaudeRunnerCancellationTests {
    static func main() throws {
        if CommandLine.arguments.contains("--fixture") {
            let record = URL(fileURLWithPath: CommandLine.arguments[2])
            precondition(CommandLine.arguments.contains(ClaudeSubscriptionPolicy.settings))
            precondition(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] == nil)
            if CommandLine.arguments.contains("-p") {
                try Data("model-started".utf8).write(to: record)
            } else {
                try Data("auth-started".utf8).write(to: record)
                Thread.sleep(forTimeInterval: 0.5)
                print(
                    "{\"loggedIn\":true,\"authMethod\":\"claude.ai\",\"apiProvider\":\"firstParty\",\"subscriptionType\":\"max\"}"
                )
            }
            return
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "afto-claude-cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("claude")
        let record = root.appendingPathComponent("record")
        try Data("#!/bin/sh\nexec '\(CommandLine.arguments[0])' --fixture '\(record.path)' \"$@\"\n".utf8).write(
            to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        setenv("PATH", root.path, 1)
        setenv("HOME", root.path, 1)
        let queue = DispatchQueue(label: "afto.claude.cancellation-test")
        let runner = Runner(
            sessionId: UUID().uuidString, hasStartedBefore: false, model: nil, effort: nil, permissionMode: "default",
            queue: queue)
        let finished = DispatchSemaphore(value: 0)
        runner.onFinish = { finished.signal() }
        queue.async { runner.spawn(path: root.path, prompt: "This must never reach a model") }
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: record.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        precondition(FileManager.default.fileExists(atPath: record.path))
        queue.sync { runner.abort() }
        precondition(finished.wait(timeout: .now() + 1) == .success)
        Thread.sleep(forTimeInterval: 0.7)
        precondition(queue.sync { runner.hasExited })
        precondition((try? String(contentsOf: record, encoding: .utf8)) == "auth-started")
        let allowed = Runner(
            sessionId: UUID().uuidString, hasStartedBefore: false, model: nil, effort: nil, permissionMode: "default",
            queue: queue)
        let allowedFinished = DispatchSemaphore(value: 0)
        allowed.onFinish = { allowedFinished.signal() }
        queue.async { allowed.spawn(path: root.path, prompt: "Fixture-only generation") }
        precondition(allowedFinished.wait(timeout: .now() + 3) == .success)
        precondition((try? String(contentsOf: record, encoding: .utf8)) == "model-started")
        print("Claude cancellation: abort during auth preflight prevents every model invocation")
    }
}
