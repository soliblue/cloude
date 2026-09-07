import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("src/Assets.xcassets/AppIcon.appiconset")
let context = CGContext(
    data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.043, green: 0.063, blue: 0.082, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setLineCap(.round)
context.setLineJoin(.round)
context.setLineWidth(88)
context.setStrokeColor(CGColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1))
context.move(to: CGPoint(x: 244, y: 700))
context.addLine(to: CGPoint(x: 464, y: 512))
context.addLine(to: CGPoint(x: 244, y: 324))
context.strokePath()
context.setStrokeColor(CGColor(red: 0.43, green: 0.91, blue: 0.71, alpha: 1))
context.move(to: CGPoint(x: 572, y: 324))
context.addLine(to: CGPoint(x: 780, y: 324))
context.strokePath()
context.setFillColor(CGColor(red: 0.43, green: 0.91, blue: 0.71, alpha: 1))
context.fillEllipse(in: CGRect(x: 727, y: 647, width: 106, height: 106))
let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(
    directory.appendingPathComponent("AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))
print("Generated opaque 1024px Afto app icon")
