import Foundation

@main
struct CodexActivityTests {
    static func request(_ client: CodexClient, _ method: String, _ params: [String: Any] = [:]) {
        let done = CodexTerminalRequest<[String: Any]>()
        client.request(method, params: params) { done.finish($0) }
        if case .failure(let error) = done.wait() { preconditionFailure(error.localizedDescription) }
    }

    static func main() {
        let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 0.5)
        let state = DispatchQueue(label: "activity-test.state")
        var started = 0
        let completed = DispatchSemaphore(value: 0)
        client.observe(
            id: "fixture", on: state,
            message: { message in
                if message["method"] as? String == "turn/started" { started += 1 }
            }, disconnected: { _ in })
        request(client, "healthy")
        client.request("turn/start", params: ["threadId": "parent"], noTimeout: true) { _ in completed.signal() }
        let deadline = Date().addingTimeInterval(3)
        while state.sync(execute: { started }) == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.005) }
        precondition(client.hasPendingWork)
        request(
            client, "fixture/notification",
            ["method": "turn/started", "params": ["threadId": "helper", "turn": ["id": "helper-1"]]])
        request(
            client, "fixture/notification",
            ["method": "turn/completed", "params": ["threadId": "parent", "turn": ["id": "stale-parent"]]])
        precondition(completed.wait(timeout: .now() + 0.05) == .timedOut)
        request(
            client, "fixture/notification",
            ["method": "turn/completed", "params": ["threadId": "parent", "turn": ["id": "pending-turn"]]])
        precondition(completed.wait(timeout: .now() + 1) == .success)
        precondition(client.hasPendingWork, "helper must hold updater after parent ends")
        request(
            client, "fixture/notification",
            ["method": "turn/started", "params": ["threadId": "helper", "turn": ["id": "helper-2"]]])
        request(
            client, "fixture/notification",
            ["method": "turn/completed", "params": ["threadId": "helper", "turn": ["id": "helper-1"]]])
        precondition(client.hasPendingWork, "stale helper completion must not release newer helper")
        request(
            client, "fixture/notification",
            ["method": "turn/completed", "params": ["threadId": "helper", "turn": ["id": "helper-2"]]])
        precondition(!client.hasPendingWork, "completed generation should settle its unacknowledged start RPC")
        client.request("turn/start", params: ["threadId": "disconnect"], noTimeout: true) { _ in completed.signal() }
        request(client, "healthy")
        precondition(client.hasPendingWork)
        client.stop()
        precondition(completed.wait(timeout: .now() + 1) == .success)
        precondition(!client.hasPendingWork)
        print(
            "Native Codex activity: missing start acknowledgement, matching completion, stale completion, helper retention and disconnect cleanup passed"
        )
    }
}
