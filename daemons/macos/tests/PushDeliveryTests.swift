import Foundation

enum RemoteTunnelCredentialStore {
    static var tunnelHost: String? { nil }
    static var identity: RemoteTunnelIdentity { RemoteTunnelIdentity(macInstallationId: "test", macSecret: "test") }
}

@main
struct PushDeliveryTests {
    static func wait(until predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if predicate() { return true }
            usleep(10_000)
        }
        return predicate()
    }

    static func queueIsEmpty(_ directory: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("push-queue.json").path),
            let data = try? Data(contentsOf: directory.appendingPathComponent("push-queue.json")),
            let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return decoded.isEmpty
    }

    static func main() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("push-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        var requests: [URLRequest] = []
        var outcomes = [500, 200, 200]
        let lock = NSLock()
        let delivery = PushDelivery(
            directory: directory,
            transport: { request, completion in
                lock.lock()
                requests.append(request)
                let status = outcomes.removeFirst()
                lock.unlock()
                completion(.success(status))
            },
            hostProvider: { "remote.example" },
            identityProvider: { RemoteTunnelIdentity(macInstallationId: "mac-1", macSecret: "secret") }
        )
        delivery.register(deviceId: "device-1", token: String(repeating: "a", count: 32), environment: "production")
        delivery.enqueueNotification(
            sessionId: "session-1", title: "Done", body: "Open", kind: "completed", eventId: "event-1")
        precondition(
            wait {
                lock.lock()
                defer { lock.unlock() }
                return requests.count == 1
            })
        delivery.flushNow()
        precondition(
            wait {
                lock.lock()
                let complete = requests.count == 3
                lock.unlock()
                return complete && queueIsEmpty(directory)
            })
        lock.lock()
        let methods = requests.compactMap(\.httpMethod)
        lock.unlock()
        precondition(methods == ["PUT", "PUT", "POST"])
        let concurrentDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "push-concurrent-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: concurrentDirectory) }
        let concurrentLock = NSLock()
        var concurrentCount = 0
        let concurrent = PushDelivery(
            directory: concurrentDirectory,
            transport: { _, completion in
                concurrentLock.lock()
                concurrentCount += 1
                concurrentLock.unlock()
                completion(.success(200))
            },
            hostProvider: { "remote.example" },
            identityProvider: { RemoteTunnelIdentity(macInstallationId: "mac-1", macSecret: "secret") }
        )
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                concurrent.enqueueNotification(
                    sessionId: "session-2", title: "Done", body: "Open", kind: "completed", eventId: "same-event")
                group.leave()
            }
        }
        precondition(group.wait(timeout: .now() + 3) == .success)
        concurrent.flushNow()
        precondition(
            wait {
                concurrentLock.lock()
                let count = concurrentCount
                concurrentLock.unlock()
                return count == 1 && queueIsEmpty(concurrentDirectory)
            })
        concurrentLock.lock()
        precondition(concurrentCount == 1)
        concurrentLock.unlock()
        let corruptDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "push-corrupt-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: corruptDirectory, withIntermediateDirectories: true)
        try? Data("invalid".utf8).write(to: corruptDirectory.appendingPathComponent("push-queue.json"))
        _ = PushDelivery(
            directory: corruptDirectory, hostProvider: { "remote.example" },
            identityProvider: { RemoteTunnelIdentity(macInstallationId: "mac-1", macSecret: "secret") })
        precondition(
            (try? FileManager.default.contentsOfDirectory(atPath: corruptDirectory.path).contains(where: {
                $0.hasPrefix("push-queue.corrupt-")
            })) == true)
        defer { try? FileManager.default.removeItem(at: corruptDirectory) }
        print("Push delivery: ordering, retry, idempotency and quarantine passed")
    }
}
