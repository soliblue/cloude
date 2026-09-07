import Foundation

@main struct ChatImageTests {
    static func main() throws {
        let input: [String: Any] = ["type": "imageGeneration", "status": "inProgress"]
        let completed: [String: Any] = [
            "type": "imageGeneration", "status": "completed", "savedPath": "/work/diagram.png",
            "result": "not-base64-and-not-a-url", "failure": NSNull(),
        ]
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: completed), as: UTF8.self)
        let image = ChatImageGeneration(input: input, result: encoded)
        precondition(
            image.statusLabel == "Generated image" && image.previewPath(relativeTo: nil) == "/work/diagram.png")
        precondition(image.result == "not-base64-and-not-a-url" && image.failure == nil)
        let limited = ChatImageGeneration(
            input: [
                "status": "completed",
                "failure": ["type": "usageLimitExceeded", "limitId": "image_generation", "resetsAt": 1_788_800_000],
            ], result: nil)
        precondition(limited.statusLabel == "Image generation failed")
        precondition(limited.limitId == "image_generation" && limited.resetsAt?.timeIntervalSince1970 == 1_788_800_000)
        let malformed = ChatImageGeneration(
            input: ["savedPath": 12, "failure": ["type": "usageLimitExceeded", "resetsAt": "invalid"]], result: "{bad")
        precondition(malformed.savedPath == nil && malformed.resetsAt == nil && malformed.result == "{bad")
        let legacy = ChatImageGeneration(
            input: ["status": "completed", "savedPath": "images/out.png", "result": "legacy opaque"],
            result: "legacy opaque")
        precondition(
            legacy.previewPath(relativeTo: "/work") == "/work/images/out.png" && legacy.result == "legacy opaque")
        precondition(legacy.previewPath(relativeTo: nil) == nil)
        let empty = ChatImageGeneration(input: [:], result: nil)
        precondition(
            empty.result == nil && empty.previewPath(relativeTo: "/work") == nil
                && empty.statusLabel == "Image generation")
        for path in [
            "https://example.com/image.png", "file:///etc/passwd", "//example.com/image.png", "../outside.png",
            "~/.secret.png", "nul\u{0}.png",
        ] {
            precondition(
                ChatImageGeneration(input: ["savedPath": path], result: nil).previewPath(relativeTo: "/work") == nil,
                path)
        }
        let noPath = ChatImageGeneration(input: ["status": "completed"], result: "https://example.com/not-a-preview")
        precondition(
            noPath.previewPath(relativeTo: "/work") == nil && noPath.result == "https://example.com/not-a-preview")
        print(
            "PASS image generation: full and legacy results, safe saved paths, quota reset, malformed/missing fields, opaque result retained without decoding or fetching"
        )
    }
}
