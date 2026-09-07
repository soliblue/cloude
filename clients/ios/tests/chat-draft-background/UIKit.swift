import Foundation

public struct UIBackgroundTaskIdentifier: Equatable, Sendable {
    public let rawValue: Int
    public static let invalid = UIBackgroundTaskIdentifier(rawValue: -1)
}

@MainActor public final class UIApplication {
    public static let shared = UIApplication()
    public var acquired: [UIBackgroundTaskIdentifier] = []
    public var ended: [UIBackgroundTaskIdentifier] = []
    public var expirations: [@Sendable () -> Void] = []
    public var rejectNext = false

    public func beginBackgroundTask(
        withName: String?, expirationHandler: @escaping @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        expirations.append(expirationHandler)
        if rejectNext {
            rejectNext = false
            return .invalid
        }
        let token = UIBackgroundTaskIdentifier(rawValue: acquired.count)
        acquired.append(token)
        return token
    }

    public func endBackgroundTask(_ token: UIBackgroundTaskIdentifier) { ended.append(token) }
}
