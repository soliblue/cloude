import Foundation

enum DaemonVersion {
    static let current = "dev"
    static let platform = "macos"
    static var isDev: Bool { current == "dev" }
}
