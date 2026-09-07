@MainActor
final class PushRegistrationCore {
    private var registered: Set<PushRegistrationKey> = []
    private var inFlight: Set<PushRegistrationKey> = []
    private var active: Set<PushRegistrationKey> = []

    func sync(_ keys: Set<PushRegistrationKey>) {
        active = keys
        registered = registered.intersection(keys)
    }

    func isRegistered(_ key: PushRegistrationKey) -> Bool { registered.contains(key) }

    func isInFlight(_ key: PushRegistrationKey) -> Bool { inFlight.contains(key) }

    func register(
        _ key: PushRegistrationKey, transport: @escaping (PushRegistrationKey) async -> Int
    ) async -> Bool {
        guard active.contains(key), !registered.contains(key), !inFlight.contains(key) else { return false }
        inFlight.insert(key)
        let status = await transport(key)
        inFlight.remove(key)
        let success = (200..<300).contains(status)
        if success, active.contains(key) { registered.insert(key) }
        return success
    }
}
