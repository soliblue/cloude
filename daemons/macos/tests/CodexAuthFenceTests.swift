import Foundation

@main
struct CodexAuthFenceTests {
    static func request(
        _ client: CodexClient, _ method: String, _ params: [String: Any] = [:]
    ) -> Result<[String: Any], Error> {
        let done = CodexTerminalRequest<[String: Any]>()
        client.request(method, params: params) { done.finish($0) }
        return done.wait()
    }

    static func main() throws {
        let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 0.25)
        _ = try request(client, "account/read").get()
        _ = try request(
            client, "fixture/notification",
            [
                "method": "item/commandExecution/requestApproval", "id": 9,
                "params": ["threadId": "unowned-helper", "turnId": "helper-turn"],
            ]
        ).get()
        precondition(!DaemonLifecycle.shared.reserveUpdate())
        let approval = client.pendingRequests(threadId: "unowned-helper").first!["requestId"] as! String
        _ = try request(
            client, "fixture/notification", ["method": "account/updated", "params": ["authMode": "apikey"]]
        ).get()
        precondition(!client.respond(requestId: approval, threadId: "unowned-helper", result: ["decision": "accept"]))
        for method in ["turn/start", "review/start", "turn/steer", "thread/compact/start"] {
            if case .success = request(client, method, ["threadId": "thread"]) {
                preconditionFailure("inference admitted after API-key auth update")
            }
        }
        _ = try request(client, "account/read", ["fixtureRace": true]).get()
        precondition(!client.respond(requestId: approval, threadId: "unowned-helper", result: ["decision": "accept"]))
        _ = try request(client, "account/read").get()
        precondition(client.respond(requestId: approval, threadId: "unowned-helper", result: ["decision": "accept"]))
        _ = try request(client, "healthy").get()
        precondition(!client.hasPendingWork)
        precondition(DaemonLifecycle.shared.reserveUpdate())
        if case .success = request(client, "turn/start", ["threadId": "thread"]) {
            preconditionFailure("new RPC admitted during update")
        }
        DaemonLifecycle.shared.releaseUpdate()
        _ = try request(client, "healthy").get()
        client.stop()
        print(
            "Native auth fence: immediate API-key update blocks inference and imported helper approvals, stale account response cannot clear fence, fresh subscription check recovers, updater rejects new RPCs passed"
        )
    }
}
