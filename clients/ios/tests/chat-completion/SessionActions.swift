enum SessionActions {
    static func setUnread(_ value: Bool, for session: Session) { session.hasUnread = value }
    static func setStreaming(_ value: Bool, for session: Session) { session.isStreaming = value }
    static func setNeedsAttention(_ value: Bool, for session: Session) { session.needsAttention = value }
}
