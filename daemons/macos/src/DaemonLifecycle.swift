import Foundation

final class DaemonLifecycle: @unchecked Sendable {
    static let shared = DaemonLifecycle()
    private let lock = NSLock()
    private var admissions: Set<UUID> = []
    private var updating = false

    func begin() -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        if !updating {
            let id = UUID()
            admissions.insert(id)
            return id
        }
        return nil
    }

    func observeWork() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        updating = false
        let id = UUID()
        admissions.insert(id)
        return id
    }

    func end(_ id: UUID) {
        lock.lock()
        admissions.remove(id)
        lock.unlock()
    }

    func reserveUpdate() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if admissions.isEmpty, !updating {
            updating = true
            return true
        }
        return false
    }

    func releaseUpdate() {
        lock.lock()
        updating = false
        lock.unlock()
    }

    func commitUpdate(_ action: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if updating, admissions.isEmpty {
            action()
            return true
        }
        return false
    }
}
