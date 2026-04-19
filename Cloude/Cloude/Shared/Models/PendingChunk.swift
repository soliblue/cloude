import Foundation

struct PendingChunk {
    var chunks: [Int: String]
    let totalChunks: Int
    let mimeType: String
    let size: Int64
}
