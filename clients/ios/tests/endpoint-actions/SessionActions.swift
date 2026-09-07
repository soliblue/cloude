import Foundation

enum SessionActions {
    static func detachEndpoint(for session: Session) { session.endpoint = nil }
}
