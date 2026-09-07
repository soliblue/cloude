import Foundation

struct HTTPBoundedTests {
    static func state(_ port: Int, release: Bool = false) async throws -> [String: Any] {
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "http://127.0.0.1:\(port)/\(release ? "release" : "state")")!)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    @MainActor static func run() async throws {
        let port = Int(CommandLine.arguments[1])!
        let endpoint = Endpoint(host: "127.0.0.1", port: port)
        for mode in [
            "exact206", "exact200", "unknown", "chunked", "empty", "overflow", "misleading", "header-overflow",
            "redirect",
        ] {
            let previous = DaemonVersionObserver.shared.observed.count
            let result = await HTTPClient.downloadBounded(
                endpoint: endpoint, path: "/" + mode, query: ["path": "/outside folder/é?#&.png"],
                maximumBytes: mode == "empty" ? 0 : 5)
            if ["exact206", "exact200", "unknown", "chunked", "empty"].contains(mode) {
                precondition(result?.0 == (mode == "empty" ? Data() : Data([1, 2, 3, 4, 5])), mode)
                precondition(result?.1.statusCode == (mode == "exact206" ? 206 : 200), mode)
                precondition(DaemonVersionObserver.shared.observed.count == previous + 1)
            } else {
                precondition(result == nil, mode)
                precondition(DaemonVersionObserver.shared.observed.count == previous)
            }
            let sent = (try await state(port)["requests"] as! [[String: Any]]).last!
            precondition(sent["range"] as? String == "bytes=0-\(mode == "empty" ? 0 : 5)")
            precondition(sent["auth"] as? String == "Bearer subscription-fixture")
            precondition((sent["query"] as? [String: [String]])?["path"] == ["/outside folder/é?#&.png"])
        }
        precondition(endpoint.capabilities == ["codex", "codexTerminal"])
        for mode in ["cancel", "revision", "cache"] {
            let previous = DaemonVersionObserver.shared.observed.count
            let task = Task { await HTTPClient.downloadBounded(endpoint: endpoint, path: "/hold", maximumBytes: 5) }
            for _ in 0..<100 {
                if try await state(port)["held"] as? Bool == true { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            if try await state(port)["held"] as? Bool != true { preconditionFailure("held request did not arrive") }
            if mode == "cancel" {
                task.cancel()
            } else if mode == "revision" {
                HTTPClient.invalidate(endpointId: endpoint.id)
            } else {
                endpoint.connectionRevision = UUID()
            }
            _ = try await state(port, release: true)
            let result = await task.value
            precondition(result == nil && DaemonVersionObserver.shared.observed.count == previous, mode)
            for _ in 0..<100 {
                if try await state(port)["held"] as? Bool == false { break }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        let requests = try await state(port)["requests"] as! [[String: Any]]
        let invalid = await HTTPClient.downloadBounded(endpoint: endpoint, path: "/exact200", maximumBytes: -1)
        let invalidTimeout = await HTTPClient.downloadBounded(
            endpoint: endpoint, path: "/exact200", maximumBytes: 5, timeout: .infinity)
        let cancelled = Task {
            await HTTPClient.downloadBounded(endpoint: endpoint, path: "/exact200", maximumBytes: 5)
        }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        precondition(invalid == nil && invalidTimeout == nil && cancelledResult == nil)
        if (try await state(port)["requests"] as! [[String: Any]]).count != requests.count {
            preconditionFailure("invalid request reached server")
        }
        let before = Date()
        let timedOut = await HTTPClient.downloadBounded(
            endpoint: endpoint, path: "/stall", maximumBytes: 5, timeout: 0.15)
        precondition(timedOut == nil && Date().timeIntervalSince(before) < 1.5)
        if try await state(port)["redirects"] as? Int != 0 { preconditionFailure("redirect followed") }
        for mode in [
            "exact206", "unknown", "overflow", "overflow-held", "misleading", "header-overflow", "hold", "pre-cancel",
        ] {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [HTTPBoundedURLProtocol.self]
            var receiver: HTTPBoundedDownload? = HTTPBoundedDownload(maximumBytes: 5, configuration: configuration)
            weak let released = receiver
            var request = URLRequest(url: URL(string: "https://afto-bounded.invalid/" + mode)!, timeoutInterval: 3)
            request.setValue("bytes=0-5", forHTTPHeaderField: "Range")
            request.setValue("Bearer subscription-fixture", forHTTPHeaderField: "Authorization")
            if mode == "pre-cancel" {
                let count = HTTPBoundedURLProtocol.started.withLock { $0.count }
                let task = Task { [receiver] in await receiver!.receive(request) }
                task.cancel()
                let result = await task.value
                precondition(result == nil)
                precondition(HTTPBoundedURLProtocol.started.withLock { $0.count } == count)
            } else if mode == "hold" {
                HTTPBoundedURLProtocol.pending.withLock { $0 = nil }
                let task = Task { [receiver] in await receiver!.receive(request) }
                for _ in 0..<100 where HTTPBoundedURLProtocol.pending.withLock({ $0 == nil }) {
                    try await Task.sleep(for: .milliseconds(10))
                }
                precondition(HTTPBoundedURLProtocol.pending.withLock { $0 != nil })
                task.cancel()
                let result = await task.value
                precondition(result == nil)
            } else {
                let started = Date()
                let result = await receiver!.receive(request)
                if mode == "overflow-held" { precondition(Date().timeIntervalSince(started) < 1.5) }
                precondition((result != nil) == ["exact206", "unknown"].contains(mode), mode)
            }
            receiver = nil
            for _ in 0..<100 where released != nil { try await Task.sleep(for: .milliseconds(10)) }
            precondition(released == nil, "delegate/session retained after " + mode)
        }
        print(
            "Bounded HTTP: real local206/200/chunked/no length, overflow/misleading length, auth/query, cancel/revision/timeout, denied redirects, URLProtocol chunks and delegate/session teardown passed"
        )
    }
}
