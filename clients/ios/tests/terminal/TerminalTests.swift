import Foundation

@main struct TerminalTests {
    @MainActor static func main() async throws {
        let session = Session()
        let snapshot: [String: Any] = [
            "terminalId": UUID().uuidString, "sessionId": session.id.uuidString, "path": "/srv/project",
            "status": "running", "lastSeq": 2, "createdAt": 123000, "cols": 80, "rows": 24,
        ]
        let dto = try JSONDecoder().decode(TerminalSnapshot.self, from: json(snapshot))
        let terminal = TerminalSessionStore(snapshot: dto, connectionKey: session.connectionKey)
        let raw = Data("\u{1b}[31m🙂e\u{301}\r\n\u{1b}[0m".utf8)
        terminal.apply(
            try json(["type": "terminal_output", "seq": 0, "deltaBase64": raw.prefix(8).base64EncodedString()]))
        terminal.apply(
            try json(["type": "terminal_output", "seq": 1, "deltaBase64": raw.dropFirst(8).base64EncodedString()]))
        terminal.apply(try json(["type": "terminal_output", "seq": 1, "deltaBase64": "ZHVwbGljYXRl"]))
        precondition(terminal.renderer.bytes == raw && terminal.lastSeq == 1 && !terminal.connected)
        precondition(terminal.renderer.responsePermissions == [false, false])
        terminal.apply(try json(snapshot.merging(["type": "terminal_ready"]) { _, new in new }))
        precondition(terminal.connected)
        terminal.apply(
            try json(["type": "terminal_output", "seq": 3, "deltaBase64": Data("live".utf8).base64EncodedString()]))
        precondition(terminal.renderer.responsePermissions.last == true)
        terminal.apply(try json(["type": "terminal_gap", "firstSeq": 10, "requestedAfterSeq": 3]))
        precondition(terminal.lastSeq == 9 && terminal.renderer.resets == 1 && terminal.gap != nil)
        terminal.apply(try json(["type": "terminal_gap", "firstSeq": 10, "requestedAfterSeq": 3]))
        precondition(terminal.renderer.resets == 1)
        terminal.apply(try json(["type": "terminal_output", "seq": 10, "deltaBase64": "YQ=="]))
        precondition(terminal.renderer.responsePermissions.last == false)
        terminal.apply(try json(["type": "terminal_output", "seq": 11, "deltaBase64": "not base64"]))
        precondition(terminal.lastSeq == 10)
        terminal.apply(
            try json(
                snapshot.merging(["type": "terminal_state", "seq": 11, "terminalId": "wrong", "status": "exited"]) {
                    _, new in new
                }))
        precondition(terminal.snapshot.isRunning)
        terminal.apply(
            try json(
                snapshot.merging(["type": "terminal_state", "seq": 11, "status": "exited", "exitCode": 0]) { _, new in
                    new
                }))
        precondition(!terminal.connected && !terminal.snapshot.isRunning && terminal.snapshot.exitCode == 0)
        print(
            "Passed exact ANSI/fragmented UTF8 bytes, duplicate suppression, replay reply suppression, gap reset and lifecycle identity"
        )

        let store = TerminalStore()
        HTTPClient.response = nil
        let initialRequest = store.startRequestId
        await TerminalService.start(session: session, store: store)
        precondition(store.selected == nil && store.error != nil && store.startRequestId == initialRequest)
        HTTPClient.response = (try json(snapshot), http(202))
        await TerminalService.start(session: session, store: store)
        precondition(store.selected != nil && store.startRequestId != initialRequest)
        precondition(
            HTTPClient.postBodies.prefix(2).allSatisfy {
                $0["requestId"] as? String == initialRequest.uuidString && $0["fullAccess"] as? Bool == true
                    && $0["path"] as? String == "/srv/project"
            })
        let selected = store.selected!
        selected.lastSeq = 2
        TerminalService.select(dto, session: session, store: store)
        precondition(store.selected === selected && store.selected?.lastSeq == 2)
        let stale = TerminalStore()
        HTTPClient.beforeResponse = { session.endpoint?.revision = UUID() }
        await TerminalService.start(session: session, store: stale)
        precondition(stale.selected == nil)
        HTTPClient.beforeResponse = nil
        print(
            "Passed explicit full-access start, stable creation retry, cached renderer and stale endpoint response rejection"
        )

        let writable = TerminalSessionStore(snapshot: dto, connectionKey: session.connectionKey)
        writable.connected = true
        HTTPClient.postBodies = []
        HTTPClient.response = (Data(), http(200))
        TerminalService.enqueue(Data("a".utf8), session: session, terminal: writable)
        TerminalService.enqueue(Data("b".utf8), session: session, terminal: writable)
        while !writable.inputs.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        precondition(HTTPClient.postBodies.count == 1)
        precondition(HTTPClient.postBodies[0]["sequence"] as? Int == 0)
        precondition(HTTPClient.postBodies[0]["deltaBase64"] as? String == Data("ab".utf8).base64EncodedString())
        HTTPClient.response = nil
        TerminalService.enqueue(Data([3]), session: session, terminal: writable)
        while writable.inputError == nil { try await Task.sleep(for: .milliseconds(5)) }
        precondition(writable.inputs.count == 1 && writable.inputs[0].sequence == 1)
        let pending = HTTPClient.postBodies.last!
        HTTPClient.response = (Data(), http(200))
        TerminalService.retryInput(session: session, terminal: writable)
        while !writable.inputs.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        precondition(HTTPClient.postBodies.last!["sequence"] as? Int == pending["sequence"] as? Int)
        precondition(HTTPClient.postBodies.last!["writerId"] as? String == pending["writerId"] as? String)
        precondition(HTTPClient.postBodies.last!["deltaBase64"] as? String == pending["deltaBase64"] as? String)
        precondition(writable.inputError == nil)
        let paste = Data(repeating: 120, count: 40000)
        let pasteStart = HTTPClient.postBodies.count
        TerminalService.enqueue(paste, session: session, terminal: writable)
        while !writable.inputs.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        let chunks = Array(HTTPClient.postBodies.dropFirst(pasteStart))
        precondition(chunks.compactMap { $0["sequence"] as? Int } == [2, 3, 4])
        precondition(
            chunks.compactMap { ($0["deltaBase64"] as? String).flatMap { Data(base64Encoded: $0) } }
                .reduce(Data(), +) == paste)
        print(
            "Passed coalesced ordered keyboard input and ambiguous write retry with identical writer, sequence and bytes"
        )

        let followed = TerminalSessionStore(snapshot: dto, connectionKey: session.connectionKey)
        StreamingClient.lines = [
            try json(snapshot.merging(["type": "terminal_ready"]) { _, new in new }),
            try json(["type": "terminal_output", "seq": 3, "deltaBase64": "b2s="]),
            try json(
                snapshot.merging(["type": "terminal_state", "seq": 4, "lastSeq": 4, "status": "exited", "exitCode": 0])
                { _, new in new }),
        ]
        await TerminalService.follow(session: session, terminal: followed)
        precondition(followed.lastSeq == 4 && followed.renderer.bytes == Data("ok".utf8) && !followed.connected)
        precondition(StreamingClient.queries.last?["after_seq"] == "-1" && HTTPClient.deletes == 0)
        let terminate = TerminalSessionStore(snapshot: dto, connectionKey: session.connectionKey)
        await TerminalService.terminate(session: session, terminal: terminate)
        precondition(HTTPClient.deletes == 1 && terminate.snapshot.isRunning)
        TerminalService.detach(sessionId: session.id)
        precondition(selected.renderer.closed)
        let oldHost = TerminalSessionStore(snapshot: dto, connectionKey: session.connectionKey)
        oldHost.connected = true
        oldHost.inputs = [TerminalInput(writerId: oldHost.writerId, sequence: 0, data: Data("stale".utf8))]
        session.endpoint?.revision = UUID()
        let oldPostCount = HTTPClient.postBodies.count
        let oldDeleteCount = HTTPClient.deletes
        let oldStreamCount = StreamingClient.queries.count
        TerminalService.enqueue(Data("must not send".utf8), session: session, terminal: oldHost)
        TerminalService.retryInput(session: session, terminal: oldHost)
        TerminalService.resize(cols: 40, rows: 20, session: session, terminal: oldHost)
        await TerminalService.terminate(session: session, terminal: oldHost)
        await TerminalService.follow(session: session, terminal: oldHost)
        try await Task.sleep(for: .milliseconds(150))
        precondition(HTTPClient.postBodies.count == oldPostCount && HTTPClient.deletes == oldDeleteCount)
        precondition(StreamingClient.queries.count == oldStreamCount && oldHost.inputs.count == 1)
        print(
            "Passed zero input, retry, resize, terminate or stream requests from old terminal after endpoint revision changes"
        )
        print(
            "Passed terminal stream lifecycle, close without terminate, explicit terminate awaiting native state and renderer cleanup"
        )
    }

    static func json(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
    static func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
