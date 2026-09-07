import Foundation

final class HTTPRequestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private let onObserve: () -> Void
    private var handler: (() -> Void)?
    private var cancelled = false

    init(onObserve: @escaping () -> Void = {}) {
        self.onObserve = onObserve
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func observe(_ handler: @escaping () -> Void) {
        lock.lock()
        let alreadyCancelled = cancelled
        if !alreadyCancelled { self.handler = handler }
        lock.unlock()
        if alreadyCancelled { handler() } else { onObserve() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let handler = self.handler
        self.handler = nil
        lock.unlock()
        handler?()
    }

    func stopObserving() {
        lock.lock()
        handler = nil
        lock.unlock()
    }
}
