import Foundation

struct FileNodeDTO: Decodable, Hashable, Identifiable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int?
    let modifiedAt: String?
    let mimeType: String?

    var id: String { path }
}

struct FileListingDTO: Decodable {
    let path: String
    let entries: [FileNodeDTO]
}

struct FileSearchDTO: Decodable {
    let entries: [FileNodeDTO]
}
