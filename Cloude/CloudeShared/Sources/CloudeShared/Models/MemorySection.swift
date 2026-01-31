import Foundation

public struct MemorySection: Codable, Identifiable {
    public var id: String { title }
    public let title: String
    public let content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}
