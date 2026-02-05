import Foundation

public struct RemoteSession: Codable, Identifiable {
    public let sessionId: String
    public let workingDirectory: String
    public let lastModified: Date
    public let messageCount: Int

    public var id: String { sessionId }

    public init(sessionId: String, workingDirectory: String, lastModified: Date, messageCount: Int) {
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self.lastModified = lastModified
        self.messageCount = messageCount
    }
}
