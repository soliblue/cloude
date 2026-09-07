import Foundation
import Network

@main struct AttentionBatchFixture {
    static func perform(_ method: String) {
        let completed = DispatchSemaphore(value: 0)
        CodexClient.shared.request(method) { result in
            precondition((try? result.get()) != nil)
            completed.signal()
        }
        precondition(completed.wait(timeout: .now() + 3) == .success)
    }

    static func main() {
        let log = ProcessInfo.processInfo.environment["CODEX_HOME"]! + "/rpc.jsonl"
        let head = HTTPRequest.parseHead(Data("POST /codex/attention HTTP/1.1\r\n\r\n".utf8))!
        precondition(
            CodexAttentionHandler.batch(HTTPRequest(head: head, body: Data("{\"sessionIds\":[\"unknown\"]}".utf8)))
                .status == 200)
        precondition(!FileManager.default.fileExists(atPath: log))
        precondition(
            CodexSessionStore.shared.save(sessionId: "parent-session", threadId: "parent-thread", path: "/fixture"))
        precondition(
            CodexSessionStore.shared.save(sessionId: "child-session", threadId: "child-thread", path: "/fixture"))
        CodexClient.shared.registerOwner(threadId: "parent-thread", sessionId: "parent-session")
        perform("fixture/seed")
        precondition(!CodexClient.shared.isThreadActive(threadId: "parent-thread"))
        let listener = try! NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { HTTPConnection(connection: $0).start() }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("PORT \(listener.port!.rawValue)")
                fflush(stdout)
            }
        }
        listener.start(queue: .global())
        DispatchQueue.global().async {
            while let command = readLine() {
                if command == "stop" {
                    let stopped = DispatchSemaphore(value: 0)
                    CodexClient.shared.observe(
                        id: "stop", on: .global(), message: { _ in }, disconnected: { _ in stopped.signal() })
                    CodexClient.shared.stop()
                    _ = stopped.wait(timeout: .now() + 2)
                    exit(0)
                }
                if command == "handoff" {
                    CodexClient.shared.registerOwner(threadId: "child-thread", sessionId: "child-session")
                } else {
                    perform("fixture/" + command)
                }
                print("DONE " + command)
                fflush(stdout)
            }
        }
        RunLoop.main.run()
    }
}
