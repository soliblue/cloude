import Foundation

@main struct CodexRequestsTests {
    static func request(_ client: CodexClient, _ method: String) {
        let done = DispatchSemaphore(value: 0)
        var success = false
        client.request(method) { result in
            success = (try? result.get()) != nil
            done.signal()
        }
        precondition(done.wait(timeout: .now() + 3) == .success)
        precondition(success)
    }

    static func main() throws {
        let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 2)
        let stopped = DispatchSemaphore(value: 0)
        client.observe(id: "fixture", on: .global(), message: { _ in }, disconnected: { _ in stopped.signal() })
        request(client, "fixture/requests")
        let child = client.pendingRequests(threadId: "child-thread")
        precondition(child.count == 2)
        precondition(client.pendingRequests(threadId: "parent-thread").count == 1)
        precondition(client.pendingRequests(threadId: "unknown").isEmpty)
        let permission =
            child.first { $0["method"] as? String == "item/permissions/requestApproval" }!["requestId"] as! String
        let input = child.first { $0["method"] as? String == "item/tool/requestUserInput" }!["requestId"] as! String
        precondition(permission != input)
        precondition(!client.respond(requestId: permission, threadId: "parent-thread", result: ["decision": "accept"]))
        precondition(client.pendingRequests(threadId: "child-thread").count == 2)
        precondition(
            client.respond(requestId: permission, threadId: "child-thread", result: ["decision": "acceptForSession"]))
        precondition(!client.respond(requestId: permission, threadId: "child-thread", result: ["decision": "accept"]))
        request(client, "fixture/resolved")
        precondition(client.pendingRequests(threadId: "child-thread").isEmpty)
        precondition(client.pendingRequests(threadId: "parent-thread").count == 1)
        let responses = try String(contentsOfFile: CommandLine.arguments[2] + "/responses.jsonl", encoding: .utf8)
            .split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
        precondition(responses.count == 1 && responses[0]["id"] as? Int == 7 && !(responses[0]["id"] is String))
        let result = responses[0]["result"] as! [String: Any]
        precondition(result["scope"] as? String == "session")
        precondition(
            ((result["permissions"] as? [String: Any])?["network"] as? [String: Any])?["enabled"] as? Bool == true)
        request(client, "fixture/completed")
        precondition(client.pendingRequests(threadId: "parent-thread").isEmpty)
        request(client, "fixture/requests")
        let stale = client.pendingRequests(threadId: "child-thread").first!["requestId"] as! String
        client.stop()
        precondition(stopped.wait(timeout: .now() + 3) == .success)
        precondition(client.pendingRequests(threadId: "child-thread").isEmpty)
        request(client, "fixture/requests")
        precondition(!client.pendingRequests(threadId: "child-thread").contains { $0["requestId"] as? String == stale })
        precondition(!client.respond(requestId: stale, threadId: "child-thread", result: ["decision": "accept"]))
        client.stop()
        print(
            "Native pending requests: unowned child approvals, exact thread scope, typed IDs, permission answers, single response, remote resolution and reconnect generations passed"
        )
    }
}
