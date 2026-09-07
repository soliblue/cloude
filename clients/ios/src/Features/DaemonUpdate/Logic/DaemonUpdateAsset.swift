import Foundation

struct DaemonUpdateAsset: Sendable, Equatable {
    let url: URL
    let sha256: String
    let version: String
}
