import Foundation

enum LoadedFileState: Equatable {
    case content(mimeType: String, size: Int64, truncated: Bool)
    case thumbnail(fullSize: Int64)
}
