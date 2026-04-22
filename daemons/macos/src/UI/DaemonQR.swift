import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum DaemonQR {
    static func image(from string: String, size: CGFloat = 220) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = filter.outputImage
        colorFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorFilter.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        if let colored = colorFilter.outputImage {
            let scale = size / colored.extent.width
            let scaled = colored.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            if let cg = CIContext().createCGImage(scaled, from: scaled.extent) {
                return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
            }
        }
        return nil
    }
}
