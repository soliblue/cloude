import Foundation

public struct PlanItem: Codable, Identifiable, Equatable {
    public var id: String { filename }
    public let filename: String
    public let title: String
    public let content: String
    public let path: String

    public init(filename: String, title: String, content: String, path: String) {
        self.filename = filename
        self.title = title
        self.content = content
        self.path = path
    }
}
