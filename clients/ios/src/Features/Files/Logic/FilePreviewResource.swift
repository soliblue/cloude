import Foundation

struct FilePreviewResource {
    let id = UUID()
    let url: URL
    let data: Data?
    let isCached: Bool
    let isTruncated: Bool
}
