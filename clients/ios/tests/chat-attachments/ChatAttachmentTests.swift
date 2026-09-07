import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main struct ChatAttachmentTests {
    static func main() async throws {
        let context = CGContext(
            data: nil, width: 4000, height: 3000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        let thumbnail = await ChatAttachmentService.thumbnail(data as Data)
        precondition(thumbnail?.width == 192 && thumbnail?.height == 144)
        let preview = await ChatAttachmentService.previewFile(data as Data)
        precondition(preview?.pathExtension == "jpeg")
        let original = try Data(contentsOf: preview!)
        precondition(original == data as Data)
        await ChatAttachmentService.removePreview(preview!)
        precondition(!FileManager.default.fileExists(atPath: preview!.path))
        let invalidThumbnail = await ChatAttachmentService.thumbnail(Data("not an image".utf8))
        let invalidPreview = await ChatAttachmentService.previewFile(Data())
        precondition(invalidThumbnail == nil && invalidPreview == nil)
        print(
            "Passed bounded thumbnail decoding, full-resolution preview preservation, temporary cleanup, and invalid image handling"
        )
    }
}
