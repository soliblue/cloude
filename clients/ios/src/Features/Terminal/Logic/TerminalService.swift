import Foundation

@MainActor enum TerminalService {
    private static var sessions: [String: TerminalSessionStore] = [:]
    private static var writes: [String: Task<Void, Never>] = [:]
    private static var resizes: [String: Task<Void, Never>] = [:]

    static func detach(sessionId: UUID) {
        for key in sessions.keys.filter({ $0.hasPrefix(sessionId.uuidString + "|") }) {
            if let terminal = sessions.removeValue(forKey: key) {
                terminal.followGeneration = UUID()
                terminal.connected = false
                terminal.renderer.onInput = { _ in }
                terminal.renderer.onResize = { _, _ in }
                terminal.renderer.close()
            }
            writes.removeValue(forKey: key)?.cancel()
            resizes.removeValue(forKey: key)?.cancel()
        }
    }

    static func select(_ snapshot: TerminalSnapshot, session: Session, store: TerminalStore) {
        let key = "\(session.connectionKey)|\(snapshot.terminalId)"
        if sessions[key] == nil {
            sessions[key] = TerminalSessionStore(snapshot: snapshot, connectionKey: session.connectionKey)
        }
        store.selected = sessions[key]
        store.selected?.snapshot = snapshot
        store.selected?.lastAccess = .now
        while sessions.count > 8 {
            if let oldest = sessions.filter({ $0.key != key && !$0.value.connected })
                .min(by: { $0.value.lastAccess < $1.value.lastAccess })
            {
                sessions.removeValue(forKey: oldest.key)?.renderer.close()
                writes.removeValue(forKey: oldest.key)?.cancel()
                resizes.removeValue(forKey: oldest.key)?.cancel()
            } else {
                break
            }
        }
    }

    static func load(session: Session, store: TerminalStore) async {
        let scope = session.connectionKey
        store.scope = scope
        store.isLoading = true
        if let endpoint = session.endpoint {
            let result = await HTTPClient.get(
                endpoint: endpoint,
                path: "/sessions/\(session.id.uuidString)/terminals", timeout: 15)
            if store.scope == scope && session.connectionKey == scope && !Task.isCancelled {
                if let (data, response) = result, response.statusCode == 200,
                    let page = try? JSONDecoder().decode(TerminalPage.self, from: data)
                {
                    store.terminals = page.terminals
                    store.error = nil
                    if let selected = store.selected,
                        let updated = page.terminals.first(where: { $0.id == selected.snapshot.id })
                    {
                        selected.snapshot = updated
                    }
                } else {
                    store.error = error(result, fallback: "Could not load terminals. Check this host connection.")
                }
                store.isLoading = false
            }
        }
    }

    static func start(session: Session, store: TerminalStore) async {
        if !store.isStarting, let endpoint = session.endpoint, let path = session.path {
            let scope = session.connectionKey
            store.scope = scope
            store.isStarting = true
            let result = await HTTPClient.post(
                endpoint: endpoint,
                path: "/sessions/\(session.id.uuidString)/terminals",
                body: [
                    "requestId": store.startRequestId.uuidString, "path": path, "fullAccess": true,
                    "cols": 80, "rows": 24,
                ], timeout: 30)
            if store.scope == scope && session.connectionKey == scope && !Task.isCancelled {
                store.isStarting = false
                if let (data, response) = result, (200..<300).contains(response.statusCode),
                    let snapshot = try? JSONDecoder().decode(TerminalSnapshot.self, from: data)
                {
                    store.startRequestId = UUID()
                    store.error = nil
                    store.terminals.removeAll { $0.id == snapshot.id }
                    store.terminals.append(snapshot)
                    select(snapshot, session: session, store: store)
                } else {
                    store.error = error(
                        result,
                        fallback: "Could not confirm the terminal started. Retry reuses the same request safely.")
                }
            }
        }
    }

    static func follow(session: Session, terminal: TerminalSessionStore) async {
        let scope = terminal.connectionKey
        let generation = UUID()
        terminal.followGeneration = generation
        if session.connectionKey == scope, let endpoint = session.endpoint {
            terminal.renderer.onInput = { [weak terminal] data in
                if let terminal, session.connectionKey == scope, terminal.canInput {
                    enqueue(data, session: session, terminal: terminal)
                }
            }
            terminal.renderer.onResize = { [weak terminal] cols, rows in
                if let terminal, session.connectionKey == scope, terminal.canInput {
                    resize(cols: cols, rows: rows, session: session, terminal: terminal)
                }
            }
            defer {
                if terminal.followGeneration == generation {
                    terminal.connected = false
                    terminal.renderer.onInput = { _ in }
                    terminal.renderer.onResize = { _, _ in }
                }
            }
            var failures = 0
            while !Task.isCancelled && session.connectionKey == scope && terminal.followGeneration == generation {
                terminal.replayThrough = max(terminal.replayThrough, terminal.snapshot.lastSeq)
                var iterator = StreamingClient.get(
                    endpoint: endpoint,
                    path: "/sessions/\(session.id.uuidString)/terminals/\(terminal.snapshot.id)/stream",
                    query: ["after_seq": String(terminal.lastSeq)]
                ).makeAsyncIterator()
                while let line = try? await iterator.next(),
                    !Task.isCancelled && session.connectionKey == scope
                        && terminal.followGeneration == generation
                {
                    if terminal.error != nil { terminal.error = nil }
                    failures = 0
                    let wasConnected = terminal.connected
                    terminal.apply(line)
                    if terminal.connected && !wasConnected {
                        resize(
                            cols: terminal.renderer.cols, rows: terminal.renderer.rows,
                            session: session, terminal: terminal)
                    }
                    await Task.yield()
                }
                if terminal.followGeneration != generation { break }
                terminal.connected = false
                if !terminal.snapshot.isRunning || Task.isCancelled || session.connectionKey != scope { break }
                failures += 1
                terminal.error = "Connection interrupted. Reconnecting; input is paused."
                if failures >= 3 {
                    let response = await HTTPClient.get(
                        endpoint: endpoint,
                        path: "/sessions/\(session.id.uuidString)/terminals", timeout: 15)
                    if session.connectionKey == scope,
                        let (data, http) = response, http.statusCode == 200,
                        let page = try? JSONDecoder().decode(TerminalPage.self, from: data),
                        !page.terminals.contains(where: { $0.id == terminal.snapshot.id })
                    {
                        terminal.error =
                            "This terminal is no longer available. The host may have restarted. Open a new terminal."
                        break
                    }
                }
                try? await Task.sleep(for: .seconds(min(failures, 5)))
            }
        }
    }

    static func enqueue(_ data: Data, session: Session, terminal: TerminalSessionStore) {
        if terminal.connectionKey == session.connectionKey && terminal.canInput && !data.isEmpty {
            if data.count + terminal.inputs.reduce(0, { $0 + $1.data.count }) <= 262144 {
                for start in stride(from: 0, to: data.count, by: 16384) {
                    let chunk = data.subdata(in: start..<min(start + 16384, data.count))
                    if let last = terminal.inputs.last, last.sequence != terminal.inFlightSequence,
                        last.data.count + chunk.count <= 16384
                    {
                        terminal.inputs[terminal.inputs.count - 1] = TerminalInput(
                            writerId: last.writerId,
                            sequence: last.sequence, data: last.data + chunk)
                    } else {
                        terminal.inputs.append(
                            TerminalInput(
                                writerId: terminal.writerId,
                                sequence: terminal.nextInputSequence, data: chunk))
                        terminal.nextInputSequence += 1
                    }
                }
                retryInput(session: session, terminal: terminal)
            } else {
                terminal.inputError = "Input queue is full. Wait for pending input before pasting more."
            }
        }
    }

    static func retryInput(session: Session, terminal: TerminalSessionStore) {
        let key = "\(session.connectionKey)|\(terminal.snapshot.id)"
        if terminal.connectionKey == session.connectionKey, writes[key] == nil, terminal.connected,
            terminal.snapshot.isRunning
        {
            terminal.inputError = nil
            writes[key] = Task {
                await drain(session: session, terminal: terminal)
                writes.removeValue(forKey: key)
            }
        }
    }

    private static func drain(session: Session, terminal: TerminalSessionStore) async {
        let scope = terminal.connectionKey
        if session.connectionKey == scope, let endpoint = session.endpoint {
            while !terminal.inputs.isEmpty, !Task.isCancelled && session.connectionKey == scope {
                try? await Task.sleep(for: .milliseconds(25))
                if Task.isCancelled || session.connectionKey != scope { break }
                let input = terminal.inputs[0]
                terminal.inFlightSequence = input.sequence
                let result = await HTTPClient.post(
                    endpoint: endpoint,
                    path: "/sessions/\(session.id.uuidString)/terminals/\(terminal.snapshot.id)/input",
                    body: input.body, timeout: 15)
                if session.connectionKey != scope || Task.isCancelled { break }
                if let (_, response) = result, response.statusCode == 200 {
                    terminal.inputs.removeFirst()
                    terminal.inFlightSequence = nil
                } else {
                    terminal.inputError = error(
                        result,
                        fallback: "Input delivery is uncertain. Retry safely with the same writer and sequence.")
                    break
                }
            }
        }
    }

    static func resize(cols: Int, rows: Int, session: Session, terminal: TerminalSessionStore) {
        if terminal.connectionKey == session.connectionKey, (1...1000).contains(cols), (1...1000).contains(rows),
            cols != terminal.snapshot.cols || rows != terminal.snapshot.rows
        {
            let scope = session.connectionKey
            let key = "\(scope)|\(terminal.snapshot.id)"
            resizes[key]?.cancel()
            resizes[key] = Task {
                try? await Task.sleep(for: .milliseconds(120))
                if !Task.isCancelled, session.connectionKey == scope, let endpoint = session.endpoint {
                    let result = await HTTPClient.post(
                        endpoint: endpoint,
                        path: "/sessions/\(session.id.uuidString)/terminals/\(terminal.snapshot.id)/resize",
                        body: ["cols": cols, "rows": rows])
                    if !Task.isCancelled, session.connectionKey == scope,
                        result?.1.statusCode != 200
                    {
                        terminal.error = error(result, fallback: "Could not resize the remote terminal.")
                    }
                }
            }
        }
    }

    static func terminate(session: Session, terminal: TerminalSessionStore) async {
        if terminal.connectionKey == session.connectionKey, !terminal.terminating, let endpoint = session.endpoint {
            let scope = session.connectionKey
            terminal.terminating = true
            let result = await HTTPClient.delete(
                endpoint: endpoint,
                path: "/sessions/\(session.id.uuidString)/terminals/\(terminal.snapshot.id)", timeout: 15)
            if session.connectionKey == scope && !Task.isCancelled {
                terminal.terminating = false
                if result?.1.statusCode != 200 {
                    terminal.error = error(result, fallback: "Could not terminate this terminal. Check the connection.")
                }
            }
        }
    }

    private static func error(_ result: (Data, HTTPURLResponse)?, fallback: String) -> String {
        result.flatMap { try? JSONDecoder().decode(TerminalError.self, from: $0.0).error } ?? fallback
    }
}
