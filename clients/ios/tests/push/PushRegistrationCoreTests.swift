import Foundation

@main
struct PushRegistrationCoreTests {
    @MainActor static func main() async {
        let core = PushRegistrationCore()
        let endpoint = UUID()
        let revision = UUID()
        let key = PushRegistrationKey(endpointId: endpoint, revision: revision, token: "token-a")
        core.sync([key])
        var calls = 0
        let first = await core.register(key) { _ in
            calls += 1
            return 503
        }
        let failedRegistered = core.isRegistered(key)
        precondition(!first && calls == 1 && !failedRegistered)
        let second = await core.register(key) { _ in
            calls += 1
            return 201
        }
        let successfulRegistered = core.isRegistered(key)
        precondition(second && calls == 2 && successfulRegistered)
        let duplicate = await core.register(key) { _ in
            calls += 1
            return 204
        }
        precondition(!duplicate && calls == 2)
        let changed = PushRegistrationKey(endpointId: endpoint, revision: UUID(), token: "token-b")
        core.sync([key, changed])
        let stale = await core.register(changed) { _ in 204 }
        let changedRegistered = core.isRegistered(changed)
        precondition(stale && changedRegistered && successfulRegistered)
        let staleKey = PushRegistrationKey(endpointId: endpoint, revision: UUID(), token: "token-c")
        let replacement = PushRegistrationKey(endpointId: endpoint, revision: UUID(), token: "token-d")
        core.sync([staleKey])
        var readyContinuation: AsyncStream<Void>.Continuation?
        let ready = AsyncStream<Void> { readyContinuation = $0 }
        var releaseContinuation: AsyncStream<Void>.Continuation?
        let release = AsyncStream<Void> { releaseContinuation = $0 }
        var readyIterator = ready.makeAsyncIterator()
        var releaseIterator = release.makeAsyncIterator()
        let pending = Task { @MainActor in
            await core.register(staleKey) { _ in
                readyContinuation?.yield(())
                _ = await releaseIterator.next()
                return 204
            }
        }
        _ = await readyIterator.next()
        let inFlightDuplicate = await core.register(staleKey) { _ in 500 }
        precondition(!inFlightDuplicate && core.isInFlight(staleKey))
        core.sync([replacement])
        releaseContinuation?.yield(())
        _ = await pending.value
        precondition(!core.isRegistered(staleKey))
        print("Push registration core: retries, success-only marking, deduplication and revision/token fencing passed")
    }
}
