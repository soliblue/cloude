import Foundation

public struct FileEntry: Codable, Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date
    public let mimeType: String?

    public init(name: String, path: String, isDirectory: Bool, size: Int64, modified: Date, mimeType: String?) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.mimeType = mimeType
    }
}
