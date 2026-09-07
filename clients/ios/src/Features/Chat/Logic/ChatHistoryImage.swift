import CryptoKit
import Foundation
import ImageIO

enum ChatHistoryImage {
    @concurrent
    static func resolve(
        _ inputs: [(String, String)], sources: [String], images: [Data]
    ) async -> (sources: [String], images: [Data]) {
        var existing: [String: Data] = [:]
        for (source, data) in zip(sources, images) where !data.isEmpty { existing[source] = data }
        var result: (sources: [String], images: [Data]) = ([], [])
        var remaining = 20_971_520
        for (type, value) in inputs.prefix(20) where !Task.isCancelled {
            let index = result.sources.count
            if type == "localImage", validPath(value) {
                let data = existing[value].flatMap { $0.count <= remaining ? $0 : nil } ?? Data()
                result.sources.append(value)
                result.images.append(data)
                remaining -= data.count
            } else if type == "image", value.utf8.count <= 27_962_156,
                let comma = value.firstIndex(of: ","),
                value[..<comma].lowercased().hasPrefix("data:image/"),
                value[..<comma].lowercased().hasSuffix(";base64")
            {
                let source = "inline:" + SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
                if let data = existing[source] ?? Data(base64Encoded: String(value[value.index(after: comma)...])),
                    !data.isEmpty, data.count <= remaining
                {
                    result.sources.append(source)
                    result.images.append(data)
                    remaining -= data.count
                }
            }
            if result.sources.count == index {
                result.sources.append("unavailable:\(index)")
                result.images.append(Data())
            }
        }
        return result
    }

    nonisolated static func validPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.hasPrefix("//") && path.utf8.count <= 4096
            && !path.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    @concurrent
    static func validRaster(_ data: Data) async -> Bool {
        if let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            CGImageSourceGetStatus(source) == .statusComplete,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double,
            width > 0, height > 0, width * height <= 100_000_000
        {
            return true
        }
        return false
    }
}
