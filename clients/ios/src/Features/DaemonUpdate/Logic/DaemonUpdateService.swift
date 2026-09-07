import CryptoKit
import Foundation

enum DaemonUpdateService {
    static func latestAsset(tagPrefix: String, assetName: String) async -> DaemonUpdateAsset? {
        let url = URL(string: "https://api.github.com/repos/\(DaemonUpdate.repo)/releases?per_page=100")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        {
            return selectAsset(data, tagPrefix: tagPrefix, assetName: assetName)
        }
        return nil
    }

    static func selectAsset(_ data: Data, tagPrefix: String, assetName: String) -> DaemonUpdateAsset? {
        var selected: DaemonUpdateAsset?
        if let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for release in releases {
                if release["draft"] as? Bool == false, release["prerelease"] as? Bool == false,
                    let tag = release["tag_name"] as? String, tag.hasPrefix(tagPrefix),
                    DaemonUpdateVersionCompare.parts(String(tag.dropFirst(tagPrefix.count))) != nil,
                    let assets = release["assets"] as? [[String: Any]],
                    let asset = assets.first(where: { $0["name"] as? String == assetName }),
                    let rawURL = asset["browser_download_url"] as? String, let url = URL(string: rawURL),
                    url.scheme == "https", url.host == "github.com", url.user == nil, url.password == nil,
                    url.port == nil, url.query == nil, url.fragment == nil,
                    url.path == "/\(DaemonUpdate.repo)/releases/download/\(tag)/\(assetName)",
                    let digest = asset["digest"] as? String,
                    digest.range(of: "^sha256:[a-fA-F0-9]{64}$", options: .regularExpression) != nil
                {
                    let candidate = DaemonUpdateAsset(
                        url: url, sha256: String(digest.dropFirst(7)).lowercased(),
                        version: String(tag.dropFirst(tagPrefix.count)))
                    if selected == nil || DaemonUpdateVersionCompare.isOlder(selected!.version, than: candidate.version)
                    {
                        selected = candidate
                    }
                }
            }
        }
        return selected
    }

    @concurrent static func downloadToTemp(_ asset: DaemonUpdateAsset, suggestedName: String) async -> URL? {
        if let (temporary, response) = try? await URLSession.shared.download(from: asset.url) {
            defer { try? FileManager.default.removeItem(at: temporary) }
            if (response as? HTTPURLResponse)?.statusCode == 200,
                let data = try? Data(contentsOf: temporary, options: .mappedIfSafe),
                SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == asset.sha256
            {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("afto-installer-\(UUID())")
                let destination = folder.appendingPathComponent(suggestedName)
                if (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil,
                    (try? FileManager.default.moveItem(at: temporary, to: destination)) != nil
                {
                    return destination
                }
            }
        }
        return nil
    }

    static func linuxInstallCommand(asset: DaemonUpdateAsset) -> String {
        let script =
            "set -euo pipefail; stage=$(mktemp -d); trap 'rm -rf -- \"$stage\"' EXIT; curl -fsSL '\(asset.url.absoluteString)' -o \"$stage/agent.tar.gz\"; printf '%s  %s\\n' '\(asset.sha256)' \"$stage/agent.tar.gz\" | sha256sum --check --status; tar -xzf \"$stage/agent.tar.gz\" -C \"$stage\"; cd \"$stage/release\"; bash install.sh"
        return "bash -c '" + script.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    static func latestLinuxInstallCommand() async -> String? {
        if let asset = await latestAsset(tagPrefix: DaemonUpdate.linuxTagPrefix, assetName: DaemonUpdate.linuxAssetName)
        {
            return linuxInstallCommand(asset: asset)
        }
        return nil
    }
}
