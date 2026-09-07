import Foundation

enum SessionActions {
    static func setNeedsAttention(_ value: Bool, for session: Session) { session.needsAttention = value }
}
