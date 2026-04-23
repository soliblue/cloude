import Foundation

enum CloudflaredBinary {
    static var url: URL? {
        if let bundled = Bundle.main.url(forResource: "cloudflared", withExtension: nil) {
            return bundled
        }
        return [
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared",
            "/usr/bin/cloudflared",
        ]
        .map { URL(fileURLWithPath: $0) }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
