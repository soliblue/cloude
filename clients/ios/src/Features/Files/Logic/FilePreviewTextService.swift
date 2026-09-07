import Foundation

enum FilePreviewTextService {
    @concurrent
    static func chunks(_ data: Data) async -> [String] {
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
        return stride(from: 0, to: lines.count, by: 100).map { offset in
            lines[offset..<min(offset + 100, lines.count)].joined(separator: "\n")
        }
    }
}
