import CryptoKit
import Foundation

@main struct DaemonReleaseTests {
    static func main() throws {
        let prefix = DaemonUpdate.linuxTagPrefix
        let name = DaemonUpdate.linuxAssetName
        func release(
            _ version: String, draft: Bool = false, prerelease: Bool = false, url: String? = nil, digest: String? = nil
        ) -> [String: Any] {
            [
                "tag_name": prefix + version, "draft": draft, "prerelease": prerelease,
                "assets": [
                    [
                        "name": name,
                        "browser_download_url": url
                            ?? "https://github.com/soliblue/cloude/releases/download/\(prefix)\(version)/\(name)",
                        "digest": digest ?? "sha256:" + String(repeating: "a", count: 64),
                    ]
                ],
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: [
            release("2027.01.01.1", draft: true), release("2027.01.01.2", prerelease: true),
            release("2027.bad.1"), release("2027.01.01.3", url: "http://github.com/unsafe"),
            release("2027.01.01.4", url: "https://example.com/unsafe"),
            release("2027.01.01.5", digest: "sha256:invalid"),
            release("2026.07.04.1"), release("2026.09.07.1"), release("2026.08.01.1"),
        ])
        let asset = DaemonUpdateService.selectAsset(data, tagPrefix: prefix, assetName: name)!
        precondition(asset.version == "2026.09.07.1")
        precondition(DaemonUpdateVersionCompare.isOlder("2026.7.4.1", than: "2026.9.7.1"))
        precondition(!DaemonUpdateVersionCompare.isOlder("1.2.3", than: "1.2.3.0"))
        for invalid in ["", "1.2", "1..3", "1.2.bad", "1.2.3.4.5", "999999999999999999999999999.2.3", "١.٢.٣"] {
            precondition(DaemonUpdateVersionCompare.parts(invalid) == nil)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let archive = try Data(contentsOf: directory.appendingPathComponent("fixture.tar.gz"))
        let digest = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        let valid = DaemonUpdateAsset(url: asset.url, sha256: digest, version: asset.version)
        try DaemonUpdateService.linuxInstallCommand(asset: valid).write(
            to: directory.appendingPathComponent("valid.sh"), atomically: true, encoding: .utf8)
        try DaemonUpdateService.linuxInstallCommand(asset: asset).write(
            to: directory.appendingPathComponent("invalid.sh"), atomically: true, encoding: .utf8)
        print("PASS published numeric release selection, trusted asset URL/digest and version validation")
    }
}
