import Foundation
import Network

@main
struct CodexTerminalTests {
    static func wait(_ label: String, _ predicate: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(predicate(), label)
    }

    static func main() async throws {
        let client = CodexClient(
            executablePath: ProcessInfo.processInfo.environment["CLOUDE_CODEX_BIN"]!, requestTimeout: 0.25)
        let terminal = CodexTerminal(client: client, maxOutputBytes: 2048)
        let slow = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("slow")
        try FileManager.default.createDirectory(at: slow, withIntermediateDirectories: true)
        let starting = DispatchGroup()
        let startState = DispatchQueue(label: "terminal-test.starts")
        var startIds: [String] = []
        let startId = UUID().uuidString
        for _ in 0..<6 {
            starting.enter()
            DispatchQueue.global().async {
                let result = terminal.start(
                    sessionId: "preflight", requestId: startId, cwd: slow.path, rows: 24, cols: 80)
                if case .success(let value) = result {
                    startState.sync { startIds.append(value["terminalId"] as! String) }
                }
                starting.leave()
            }
        }
        await wait("pending preflight tracked") {
            terminal.hasActiveWork && terminal.list(sessionId: "preflight").isEmpty
        }
        precondition(!DaemonLifecycle.shared.reserveUpdate())
        precondition(starting.wait(timeout: .now() + 3) == .success)
        precondition(startIds.count == 6 && Set(startIds).count == 1)
        _ = try terminal.terminate(sessionId: "preflight", terminalId: startIds[0]).get()
        await wait("preflight terminal settled") { !terminal.hasActiveWork }
        try FileManager.default.removeItem(at: slow.deletingLastPathComponent())
        let id = UUID().uuidString
        let terminalId =
            try terminal.start(sessionId: "SESSION", requestId: id, cwd: "/tmp", rows: 24, cols: 80).get()["terminalId"]
            as! String
        let replayId =
            try terminal.start(sessionId: "session", requestId: id.lowercased(), cwd: "/tmp", rows: 24, cols: 80).get()[
                "terminalId"] as! String
        precondition(terminalId == replayId)
        precondition(terminal.list(sessionId: "session").count == 1)
        if case .success = terminal.start(sessionId: "session", requestId: id, cwd: "/", rows: 24, cols: 80) {
            preconditionFailure("conflicting start passed")
        }
        if case .success = terminal.start(
            sessionId: "session", requestId: UUID().uuidString, cwd: "/not-an-existing-afto-directory", rows: 24,
            cols: 80)
        {
            preconditionFailure("missing cwd passed")
        }
        let denied = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("denied")
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
        if case .success = terminal.start(
            sessionId: "session", requestId: UUID().uuidString, cwd: denied.path, rows: 24, cols: 80)
        {
            preconditionFailure("custom inference config passed")
        }
        try FileManager.default.removeItem(at: denied.deletingLastPathComponent())
        await wait("initial output") {
            terminal.stream(sessionId: "session", terminalId: terminalId, cursor: -1)?.contains {
                $0["type"] as? String == "terminal_output"
            } == true
        }
        let state = DispatchQueue(label: "terminal-test.state")
        var live: [[String: Any]] = []
        var ended = false
        terminal.subscribe(sessionId: "session", terminalId: terminalId, cursor: -1, subscriberId: "live") {
            event, done in
            state.sync {
                if let event { live.append(event) }
                ended = done
            }
        }
        let writer = UUID().uuidString
        let bytes = Data("echo hi\n".utf8)
        if case .success(false) = terminal.input(
            sessionId: "session", terminalId: terminalId, writerId: writer, sequence: 0, data: bytes, close: false)
        {
        } else {
            preconditionFailure()
        }
        if case .success(true) = terminal.input(
            sessionId: "session", terminalId: terminalId, writerId: writer.lowercased(), sequence: 0, data: bytes,
            close: false)
        {
        } else {
            preconditionFailure()
        }
        if case .success = terminal.input(
            sessionId: "session", terminalId: terminalId, writerId: writer, sequence: 0, data: Data("other".utf8),
            close: false)
        {
            preconditionFailure("conflicting bytes passed")
        }
        if case .success = terminal.input(
            sessionId: "session", terminalId: terminalId, writerId: writer, sequence: 2, data: bytes, close: false)
        {
            preconditionFailure("skipped sequence passed")
        }
        _ = try terminal.input(
            sessionId: "session", terminalId: terminalId, writerId: writer, sequence: 1, data: Data("burst".utf8),
            close: false
        ).get()
        await wait("live overflow output") {
            state.sync { live.filter { $0["type"] as? String == "terminal_output" }.count == 42 }
        }
        let retained = terminal.stream(sessionId: "session", terminalId: terminalId, cursor: -1)!
        precondition(retained.count < 10)
        let sequences = retained.compactMap { $0["seq"] as? Int }
        precondition(sequences == Array(sequences.first!...sequences.last!))
        var gap: [[String: Any]] = []
        terminal.subscribe(sessionId: "session", terminalId: terminalId, cursor: -1, subscriberId: "gap") { event, _ in
            state.sync { if let event { gap.append(event) } }
        }
        await wait("replay gap") { state.sync { gap.last?["type"] as? String == "terminal_ready" } }
        precondition(state.sync { gap.first?["type"] as? String == "terminal_gap" })
        terminal.unsubscribe(terminalId: terminalId, subscriberId: "gap")
        let gapCount = state.sync { gap.count }
        for command in ["deny", "ambiguous"] {
            let writer = UUID().uuidString
            for _ in 0..<2 {
                if case .success = terminal.input(
                    sessionId: "session", terminalId: terminalId, writerId: writer, sequence: 0,
                    data: Data(command.utf8), close: false)
                {
                    preconditionFailure("failed write acknowledged")
                }
            }
        }
        precondition(
            state.sync {
                live.filter { $0["deltaBase64"] as? String == Data("ambiguous-write-once".utf8).base64EncodedString() }
                    .count == 1
            })
        precondition(state.sync { gap.count == gapCount })
        if case .success = terminal.resize(sessionId: "session", terminalId: terminalId, rows: 666, cols: 100) {
            preconditionFailure("failed resize acknowledged")
        }
        precondition(terminal.list(sessionId: "session").first?["rows"] as? Int == 24)
        _ = try terminal.resize(sessionId: "session", terminalId: terminalId, rows: 30, cols: 100).get()
        for index in 0..<40 {
            _ = try terminal.resize(sessionId: "session", terminalId: terminalId, rows: 30 + index, cols: 100).get()
        }
        precondition(terminal.stream(sessionId: "session", terminalId: terminalId, cursor: -1)!.count < 10)
        _ = try terminal.terminate(sessionId: "session", terminalId: terminalId).get()
        await wait("live stream closes") { state.sync { ended } }
        precondition(!terminal.hasActiveWork)
        precondition(terminal.list(sessionId: "session").first?["status"] as? String == "exited")
        client.stop()
        precondition(DaemonLifecycle.shared.reserveUpdate())
        if case .success = terminal.start(
            sessionId: "fenced", requestId: UUID().uuidString, cwd: "/tmp", rows: 24, cols: 80)
        {
            preconditionFailure("PTY admitted during update")
        }
        DaemonLifecycle.shared.releaseUpdate()
        let networkId =
            try CodexTerminal.shared.start(
                sessionId: "http", requestId: UUID().uuidString, cwd: "/tmp", rows: 24, cols: 80
            ).get()["terminalId"] as! String
        let listener = try NWListener(using: .tcp, on: .any)
        let listenerReady = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { listenerReady.signal() } }
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            let head = HTTPRequest.parseHead(
                Data("GET /sessions/http/terminal/\(networkId)/stream?after_seq=-1 HTTP/1.1\r\n\r\n".utf8))!
            let response = CodexTerminalHandler.stream(
                HTTPRequest(head: head, body: Data()), params: ["id": "http", "terminalId": networkId])
            precondition(response.status == 200)
            if case .streamed(let stream) = response.body {
                connection.send(
                    content: response.serializeHeaders(), completion: .contentProcessed { _ in stream(connection) })
            } else {
                preconditionFailure("stream is buffered")
            }
        }
        listener.start(queue: .global())
        precondition(listenerReady.wait(timeout: .now() + 3) == .success)
        let connection = NWConnection(host: "127.0.0.1", port: listener.port!, using: .tcp)
        let receiver = CodexTerminalNetworkFixture(connection: connection)
        connection.start(queue: .global())
        receiver.receive()
        await wait("HTTP ready") { receiver.text.contains("terminal_ready") }
        precondition(!receiver.closed)
        _ = try CodexTerminal.shared.input(
            sessionId: "http", terminalId: networkId, writerId: UUID().uuidString, sequence: 0,
            data: Data("later-network-output".utf8), close: false
        ).get()
        await wait("HTTP live output after ready") {
            receiver.text.contains(Data("later-network-output".utf8).base64EncodedString())
        }
        _ = try CodexTerminal.shared.terminate(sessionId: "http", terminalId: networkId).get()
        await wait("HTTP closes after process exits") { receiver.closed }
        precondition(receiver.text.contains("exited"))
        connection.cancel()
        listener.cancel()
        CodexClient.shared.stop()
        print(
            "Native terminal: HTTP live NDJSON, exit cleanup, contiguous bounded replay gaps, metadata bounds, start dedup, cwd/config guards, ordered input, ambiguous no-duplicate writes and honest resize acknowledgments passed"
        )
    }
}
