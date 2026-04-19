import Foundation

public struct GitCommit: Codable, Identifiable, Equatable {
    public var id: String { hash }
    public let hash: String
    public let message: String
    public let author: String
    public let date: Date

    public init(hash: String, message: String, author: String, date: Date) {
        self.hash = hash
        self.message = message
        self.author = author
        self.date = date
    }
}
