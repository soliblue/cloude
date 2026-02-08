import Foundation

public struct PlanItem: Codable, Identifiable, Equatable {
    public var id: String { filename }
    public let filename: String
    public let title: String
    public let icon: String?
    public let description: String?
    public let content: String
    public let path: String

    public init(filename: String, title: String, icon: String? = nil, description: String? = nil, content: String, path: String) {
        self.filename = filename
        self.title = title
        self.icon = icon
        self.description = description
        self.content = content
        self.path = path
    }
}
