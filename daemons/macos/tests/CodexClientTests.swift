import Foundation

enum TestFailure: Error {
    case failed(String)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}

func request(
    _ client: CodexClient, method: String, timeout: TimeInterval = 3
) throws -> [String: Any] {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<[String: Any], Error>?
    client.request(method, replyOn: .global()) {
        result = $0
        semaphore.signal()
    }
    try require(semaphore.wait(timeout: .now() + timeout) == .success, "request timed out: \(method)")
    guard let result else { throw TestFailure.failed("missing result: \(method)") }
    return try result.get()
}

@main
struct CodexClientTestMain {
    static func main() {
        let fake = CommandLine.arguments[1]
        let capture = CommandLine.arguments[2]
        let client = CodexClient(executablePath: fake, requestTimeout: 0.25)
        let observerQueue = DispatchQueue(label: "codex-client-test-observer")
        let observerSemaphore = DispatchSemaphore(value: 0)
        var serverRequestID: Int?
        client.observe(id: "test", on: observerQueue) { message in
            if message["method"] as? String == "server/request" {
                serverRequestID = message["id"] as? Int
                observerSemaphore.signal()
            }
        } disconnected: { _ in
        }

        do {
            let concurrent = DispatchGroup()
            var concurrentResults = [[String: Any]]()
            var concurrentFailures = [String]()
            let resultLock = NSLock()
            for method in ["one", "two"] {
                concurrent.enter()
                client.request(method, replyOn: .global()) { result in
                    if case .success(let value) = result {
                        resultLock.lock()
                        concurrentResults.append(value)
                        resultLock.unlock()
                    } else if case .failure(let error) = result {
                        resultLock.lock()
                        concurrentFailures.append(error.localizedDescription)
                        resultLock.unlock()
                    }
                    concurrent.leave()
                }
            }
            try require(concurrent.wait(timeout: .now() + 3) == .success, "concurrent requests timed out")
            try require(concurrentResults.count == 2, "concurrent requests did not complete: \(concurrentFailures)")

            _ = try request(client, method: "serverCollision")
            try require(observerSemaphore.wait(timeout: .now() + 1) == .success, "server request was not observed")
            try require(serverRequestID != nil, "server request ID collision was not preserved")

            var rpcFailed = false
            do { _ = try request(client, method: "rpcError") } catch { rpcFailed = true }
            try require(rpcFailed, "RPC error was not propagated")

            var timedOut = false
            do { _ = try request(client, method: "timeout", timeout: 2) } catch { timedOut = true }
            try require(timedOut, "timeout request unexpectedly succeeded")
            let afterTimeout = try request(client, method: "healthy")
            try require(afterTimeout["method"] as? String == "healthy", "timeout poisoned next request")

            var crashed = false
            do { _ = try request(client, method: "crash", timeout: 2) } catch { crashed = true }
            try require(crashed, "crash request unexpectedly succeeded")
            let afterCrash = try request(client, method: "afterCrash")
            try require(afterCrash["method"] as? String == "afterCrash", "client did not restart after crash")

            var malformed = false
            do { _ = try request(client, method: "malformed", timeout: 2) } catch { malformed = true }
            try require(malformed, "malformed response unexpectedly succeeded")
            let afterMalformed = try request(client, method: "afterMalformed")
            try require(
                afterMalformed["method"] as? String == "afterMalformed", "client did not restart after malformed JSON")

            let environment = try Data(contentsOf: URL(fileURLWithPath: capture + "/environment.json"))
            let variables = try JSONSerialization.jsonObject(with: environment) as? [String: String] ?? [:]
            let countData = try Data(contentsOf: URL(fileURLWithPath: capture + "/initialize-count"))
            let initializeCount = Int(String(data: countData, encoding: .utf8) ?? "0") ?? 0
            try require(
                initializeCount == 3, "initialize was called \(initializeCount) times instead of once per process")
            try require(variables["CODEX_HOME"] == capture, "allowed Codex environment was not preserved")
            try require(variables["OPENAI_API_KEY"] == nil, "OpenAI API key leaked to child")
            try require(variables["ANTHROPIC_API_KEY"] == nil, "Anthropic API key leaked to child")
            client.stop()
            print("CodexClient protocol tests passed")
        } catch {
            fputs("CodexClient protocol tests failed: \(error)\n", stderr)
            client.stop()
            exit(1)
        }
    }
}
