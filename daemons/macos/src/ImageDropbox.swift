import Foundation
import UniformTypeIdentifiers

enum ImageDropbox {
    static func prepare(cwd: String, prompt: String, images: [[String: String]], sessionId: String) -> String {
        promptWithImagePaths(prompt: prompt, imagePaths: materialize(images: images, sessionId: sessionId))
    }

    static func promptWithImagePaths(prompt: String, imagePaths: [String]) -> String {
        if imagePaths.isEmpty { return prompt }
        let instructions = imagePaths.map { "Read the image at \($0)." }.joined(separator: " ")
        return "\(instructions)\n\n\(prompt)"
    }

    static func materialize(images: [[String: String]], sessionId: String) -> [String] {
        if images.isEmpty { return [] }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cloude-images-\(sessionId.lowercased())", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
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
        return paths
    }
}
