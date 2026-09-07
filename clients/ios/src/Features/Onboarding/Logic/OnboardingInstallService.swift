import Foundation

enum OnboardingInstallService {
    static func releasePageURL(linux: Bool) -> URL {
        URL(
            string:
                "https://github.com/soliblue/cloude/releases?q=tag%3A\(linux ? DaemonUpdate.linuxTagPrefix : DaemonUpdate.macTagPrefix)"
        )!
    }

    static func downloadInstaller() async -> URL? {
        if let asset = await DaemonUpdateService.latestAsset(
            tagPrefix: DaemonUpdate.macTagPrefix, assetName: DaemonUpdate.macAssetName)
        {
            return await DaemonUpdateService.downloadToTemp(asset, suggestedName: DaemonUpdate.macAssetName)
        }
        return nil
    }
}
