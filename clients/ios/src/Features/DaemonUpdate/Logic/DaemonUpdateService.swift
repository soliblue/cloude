import Foundation

enum DaemonUpdateService {
    static func latestAssetURL(tagPrefix: String, assetName: String) async -> URL? {
        let url = URL(string: "https://api.github.com/repos/\(DaemonUpdate.repo)/releases?per_page=20")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let (data, _) = try? await URLSession.shared.data(for: request),
            let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            for release in releases {
                if let tag = release["tag_name"] as? String,
                    tag.hasPrefix(tagPrefix),
                    let assets = release["assets"] as? [[String: Any]],
                    let asset = assets.first(where: { ($0["name"] as? String) == assetName }),
                    let urlString = asset["browser_download_url"] as? String
                {
                    return URL(string: urlString)
                }
            }
        }
        return nil
    }

    static func downloadToTemp(_ url: URL, suggestedName: String) async -> URL? {
        if let (tempURL, _) = try? await URLSession.shared.download(from: url) {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: tempURL, to: dest)
            return dest
        }
        return nil
    }

    static func linuxInstallCommand(downloadURL: URL) -> String {
        "curl -fsSL \(downloadURL.absoluteString) | tar -xz && cd release && bash install.sh"
    }
}
