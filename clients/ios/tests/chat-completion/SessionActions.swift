enum SessionActions {
    static func setStreaming(_ value: Bool, for session: Session) { session.isStreaming = value }
    static func setNeedsAttention(_ value: Bool, for session: Session) { session.needsAttention = value }
}
