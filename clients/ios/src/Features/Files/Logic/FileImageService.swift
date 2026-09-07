import Foundation
import ImageIO
import UIKit

enum FileImageService {
    @concurrent
    static func thumbnail(_ data: Data) async -> UIImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2_048,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary)
        {
            return UIImage(cgImage: image)
        }
        return nil
    }
}
