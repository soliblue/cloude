import AppKit
import Foundation

enum DaemonUpdater {
    static let repo = "Soli/cloude"
    static let assetName = "Remote-CC-Daemon.app.zip"
    static let tagPrefix = "macos-daemon-v"
    static let pollInterval: TimeInterval = 6 * 60 * 60

    static func start() {
        if DaemonVersion.isDev { return }
        Task.detached { await loop() }
    }

    private static func loop() async {
        while !Task.isCancelled {
            await checkOnce()
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    private static func checkOnce() async {
        if let release = await fetchLatestRelease(),
            DaemonVersionCompare.isNewer(release.version, than: DaemonVersion.current),
            let assetURL = release.assetURL,
            let zipURL = await download(assetURL),
            let appBundle = await unzip(zipURL),
            verifySignature(appBundle)
        {
            installAndRelaunch(newAppBundle: appBundle)
        }
    }

    private static func fetchLatestRelease() async -> ReleaseInfo? {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=20")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let (data, _) = try? await URLSession.shared.data(for: request),
            let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            for release in releases {
                if let tag = release["tag_name"] as? String,
                    tag.hasPrefix(tagPrefix),
                    let assets = release["assets"] as? [[String: Any]]
                {
                    let version = String(tag.dropFirst(tagPrefix.count))
                    let assetURL =
                        assets
                        .first(where: { ($0["name"] as? String) == assetName })?["browser_download_url"]
                        as? String
                    return ReleaseInfo(version: version, assetURL: assetURL.flatMap(URL.init))
                }
            }
        }
        return nil
    }

    private static func download(_ url: URL) async -> URL? {
        if let (tempURL, _) = try? await URLSession.shared.download(from: url) {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(
                "daemon-update-\(UUID().uuidString).zip")
            try? FileManager.default.moveItem(at: tempURL, to: dest)
            return dest
        }
        return nil
    }

    private static func unzip(_ zipURL: URL) async -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("daemon-update-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let process = Process()
        process.launchPath = "/usr/bin/unzip"
        process.arguments = ["-q", zipURL.path, "-d", dir.path]
        try? process.run()
        process.waitUntilExit()
        let app = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .first(where: { $0.pathExtension == "app" })
        return app
    }

    private static func verifySignature(_ appBundle: URL) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/codesign"
        process.arguments = ["--verify", "--deep", "--strict", appBundle.path]
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func installAndRelaunch(newAppBundle: URL) {
        let currentBundle = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent(
            "daemon-swap-\(UUID().uuidString).sh")
        let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(currentBundle.path)"
            mv "\(newAppBundle.path)" "\(currentBundle.path)"
            open "\(currentBundle.path)"
            rm -f "\(scriptPath.path)"
            """
        try? script.write(to: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [scriptPath.path]
        try? task.run()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

private struct ReleaseInfo {
    let version: String
    let assetURL: URL?
}
