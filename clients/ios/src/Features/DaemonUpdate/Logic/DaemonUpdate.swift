import Foundation

enum DaemonUpdate {
    static let minVersion = "2026.05.05.1"
    static let repo = "Soli/cloude"
    static let macAssetName = "Remote-CC-Daemon.dmg"
    static let macTagPrefix = "macos-daemon-v"
    static let linuxAssetName = "cloude-linux-daemon.tar.gz"
    static let linuxTagPrefix = "linux-daemon-v"

    static func isStale(version: String?) -> Bool {
        if let version, version != "dev" {
            return DaemonUpdateVersionCompare.isOlder(version, than: minVersion)
        }
        return false
    }
}
