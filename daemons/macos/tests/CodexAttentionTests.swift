import Foundation

struct AttentionFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct CodexAttentionTests {
    static func wait(_ predicate: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        if !predicate() { throw AttentionFailure(description: "timed out") }
    }

    static func request(_ client: CodexClient, _ method: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            client.request(method) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    static func main() async throws {
        let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 2)
        let queue = DispatchQueue(label: "attention-test-observer")
        let observed = DispatchSemaphore(value: 0)
        var requestKey: String?
        client.observe(id: "attention-test", on: queue) { message in
            if message["id"] as? Int == 700,
                let params = message["params"] as? [String: Any]
            {
                requestKey = params["requestKey"] as? String
                observed.signal()
            }
        } disconnected: { _ in
        }
        client.registerOwner(threadId: "parent-thread", sessionId: "parent-session")
        try await request(client, "trigger")
        precondition(observed.wait(timeout: .now() + 2) == .success)
        try await wait { requestKey != nil && client.attentionForThread("parent-thread").count == 1 }
        let key = requestKey!
        precondition(client.attentionForThread("parent-thread").first?["threadId"] as? String == "child-c")
        client.registerOwner(threadId: "child-b", sessionId: "child-session")
        try await wait { client.attentionForThread("parent-thread").isEmpty }
        precondition(client.attentionForThread("child-b").count == 1)
        precondition(client.respond(requestId: key, threadId: "child-c", result: ["decision": "accept"]))
        try await wait { client.attentionForThread("child-b").isEmpty }
        try await request(client, "trigger")
        try await wait { client.attentionForThread("child-b").count == 1 }
        try await request(client, "finish")
        try await wait { client.attentionForThread("child-b").isEmpty }
        try await request(client, "activity")
        try await wait { client.attentionForThread("parent-thread").first?["threadId"] as? String == "child-d" }
        client.stop()
        try await wait { client.attentionForThread("parent-thread").isEmpty }
        print("Codex attention: deep ancestry, owner handoff, response resolution, turn cleanup and disconnect passed")
    }
}
