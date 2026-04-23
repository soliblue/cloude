import Foundation

enum CloudeFileURL {
    static let scheme = "cloude"
    static let host = "file"

    static func url(for path: String) -> URL? {
        if let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            return URL(string: "\(scheme)://\(host)\(encoded)")
        }
        return nil
    }

    static func path(from url: URL) -> String? {
        if url.scheme == scheme, url.host == host { return url.path }
        return nil
    }
}
