import Foundation
import UniformTypeIdentifiers

enum ImageDropbox {
    static func prepare(cwd: String, prompt: String, images: [[String: String]]) -> String {
        if images.isEmpty { return prompt }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cloude-images-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for (index, image) in images.enumerated() {
            if let base64 = image["data"], let data = Data(base64Encoded: base64) {
                let mime = image["mediaType"] ?? "image/png"
                let ext = UTType(mimeType: mime)?.preferredFilenameExtension ?? "png"
                let file = dir.appendingPathComponent("image-\(index).\(ext)")
                if (try? data.write(to: file)) != nil {
                    paths.append(file.path)
                }
            }
        }
        if paths.isEmpty { return prompt }
        let instructions = paths.map { "Read the image at \($0)." }.joined(separator: " ")
        return "\(instructions)\n\n\(prompt)"
    }
}
