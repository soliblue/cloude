import Foundation

public struct HistoryMessage: Codable {
    public let isUser: Bool
    public let text: String
    public let timestamp: Date

    public init(isUser: Bool, text: String, timestamp: Date) {
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
    }
}
