import Foundation

enum OnboardingInstallService {
    static let releasePageURL = URL(string: "https://github.com/soliblue/cloude/releases/latest")!
    private static let installerDownloadURL =
        URL(string: "https://github.com/soliblue/cloude/releases/latest/download/Remote-CC-Daemon.dmg")!

    static func downloadInstaller() async -> URL? {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Remote-CC-Daemon.dmg")
        try? FileManager.default.removeItem(at: destination)
        if let (temporary, response) = try? await URLSession.shared.download(from: installerDownloadURL),
            let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
            (try? FileManager.default.moveItem(at: temporary, to: destination)) != nil
        {
            return destination
        }
        return nil
    }
}
