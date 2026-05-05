import Foundation

enum OnboardingInstallService {
    static let releasePageURL = URL(string: "https://github.com/soliblue/cloude/releases?q=tag%3Aagent-v")!
    private static let releasesAPIURL =
        URL(string: "https://api.github.com/repos/soliblue/cloude/releases?per_page=30")!
    private static let assetName = "Remote-CC-Daemon.dmg"
    private static let tagPrefix = "agent-v"

    static func downloadInstaller() async -> URL? {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(assetName)
        try? FileManager.default.removeItem(at: destination)
        if let installerURL = await latestMacReleaseAssetURL(),
            let (temporary, response) = try? await URLSession.shared.download(from: installerURL),
            let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
            (try? FileManager.default.moveItem(at: temporary, to: destination)) != nil
        {
            return destination
        }
        return nil
    }

    private static func latestMacReleaseAssetURL() async -> URL? {
        if let (data, _) = try? await URLSession.shared.data(from: releasesAPIURL),
            let releases = try? JSONDecoder().decode([Release].self, from: data),
            let release = releases.first(where: { $0.tag_name.hasPrefix(tagPrefix) && !$0.draft && !$0.prerelease }),
            let asset = release.assets.first(where: { $0.name == assetName })
        {
            return URL(string: asset.browser_download_url)
        }
        return nil
    }

    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }
}
