import Foundation

public enum CloudeShared {
    public static let version = "1.0.0"
}

public enum Heartbeat {
    public static let sessionId = "c1a0de00-bea7-bea7-bea7-c1a0de000000"
    public static let conversationId = UUID(uuidString: sessionId)!
}
