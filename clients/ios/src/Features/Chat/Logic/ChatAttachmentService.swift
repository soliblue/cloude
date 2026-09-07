import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ChatAttachmentService {
    @concurrent
    static func thumbnail(_ data: Data) async -> CGImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        {
            return CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 192,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary)
        }
        return nil
    }

    @concurrent
    static func previewFile(_ data: Data) async -> URL? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source),
            let fileExtension = UTType(type as String)?.preferredFilenameExtension
        {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            if (try? data.write(to: url, options: .atomic)) != nil {
                return url
            }
        }
        return nil
    }

    @concurrent
    static func removePreview(_ url: URL) async {
        try? FileManager.default.removeItem(at: url)
    }
}
