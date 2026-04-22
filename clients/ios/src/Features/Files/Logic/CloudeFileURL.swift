import Foundation

enum CloudeFileURL {
    static let scheme = "cloude"
    static let host = "file"

    static func url(for path: String) -> URL? {
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: "\(scheme)://\(host)\(encoded)")
    }

    static func path(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == host else { return nil }
        return url.path
    }
}
