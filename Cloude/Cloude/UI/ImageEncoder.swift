import UIKit

struct ImageEncoder {
    static func encodeThumbnails(_ attachedImages: [AttachedImage]) -> [String]? {
        guard !attachedImages.isEmpty else { return nil }
        return attachedImages.compactMap { attached in
            guard let image = UIImage(data: attached.data),
                  let thumbnail = image.preparingThumbnail(of: CGSize(width: 200, height: 200)),
                  let thumbData = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
            return thumbData.base64EncodedString()
        }
    }

    static func encodeFullImages(_ attachedImages: [AttachedImage]) -> [String]? {
        guard !attachedImages.isEmpty else { return nil }
        return attachedImages.map { $0.data.base64EncodedString() }
    }
}
