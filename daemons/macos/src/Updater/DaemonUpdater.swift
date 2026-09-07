import AppKit
import Foundation

enum DaemonUpdater {
    static let repo = "soliblue/cloude"
    static let assetName = "Remote-CC-Daemon.app.zip"
    static let tagPrefix = "macos-daemon-v"
    static let pollInterval: TimeInterval = 6 * 60 * 60

    static func start() {
        if DaemonVersion.isDev {
            NSLog("[DaemonUpdater] dev build, skipping update check")
            return
        }
        NSLog("[DaemonUpdater] starting, current=\(DaemonVersion.current)")
        Task.detached { await loop() }
    }

    private static func loop() async {
        while !Task.isCancelled {
            await checkOnce()
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    private static func checkOnce() async {
        if !RunnerManager.shared.isIdleForUpdate() {
            NSLog("[DaemonUpdater] active work, delaying update")
            return
        }
        NSLog("[DaemonUpdater] checking releases for repo=\(repo)")
        if let release = await fetchLatestRelease() {
            NSLog("[DaemonUpdater] found latest=\(release.version) current=\(DaemonVersion.current)")
            if DaemonVersionCompare.isNewer(release.version, than: DaemonVersion.current) {
                if let assetURL = release.assetURL {
                    NSLog("[DaemonUpdater] downloading \(assetURL.absoluteString)")
                    if let zipURL = await download(assetURL) {
                        NSLog("[DaemonUpdater] downloaded to \(zipURL.path)")
                        if let appBundle = await unzip(zipURL) {
                            NSLog("[DaemonUpdater] unzipped app at \(appBundle.path)")
                            if verifySignature(appBundle) {
                                if RunnerManager.shared.isIdleForUpdate(), DaemonLifecycle.shared.reserveUpdate() {
                                    if RunnerManager.shared.isIdleForUpdate() {
                                        NSLog("[DaemonUpdater] signature verified, swapping and relaunching")
                                        installAndRelaunch(newAppBundle: appBundle)
                                    } else {
                                        DaemonLifecycle.shared.releaseUpdate()
                                    }
                                } else {
                                    NSLog("[DaemonUpdater] work started during download, deferring swap")
                                }
                            } else {
                                NSLog("[DaemonUpdater] signature verification FAILED, aborting")
                            }
                        } else {
                            NSLog("[DaemonUpdater] unzip failed")
                        }
                    } else {
                        NSLog("[DaemonUpdater] download failed")
                    }
                } else {
                    NSLog("[DaemonUpdater] no \(assetName) asset on release")
                }
            } else {
                NSLog("[DaemonUpdater] up to date")
            }
        } else {
            NSLog("[DaemonUpdater] no release found with prefix \(tagPrefix)")
        }
    }

    private static func fetchLatestRelease() async -> ReleaseInfo? {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=20")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let (data, _) = try? await URLSession.shared.data(for: request),
            let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            return selectRelease(releases)
        }
        return nil
    }

    static func selectRelease(_ releases: [[String: Any]]) -> ReleaseInfo? {
        releases.compactMap { release in
            guard release["draft"] as? Bool != true, release["prerelease"] as? Bool != true,
                let tag = release["tag_name"] as? String, tag.hasPrefix(tagPrefix)
            else { return nil }
            let version = String(tag.dropFirst(tagPrefix.count))
            guard DaemonVersionCompare.isValid(version) else { return nil }
            let assetURL =
                (release["assets"] as? [[String: Any]])?
                .first(where: { ($0["name"] as? String) == assetName })?["browser_download_url"] as? String
            let url = assetURL.flatMap(URL.init)
            guard url?.scheme == "https", url?.host == "github.com" else { return nil }
            return ReleaseInfo(version: version, assetURL: url)
        }.max { !DaemonVersionCompare.isNewer($0.version, than: $1.version) }
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
        process.arguments = [
            "--verify", "--deep", "--strict",
            "-R=anchor apple generic and certificate leaf[subject.OU] = \"Q9U8224WWM\"",
            appBundle.path,
        ]
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    static func installAndRelaunch(
        newAppBundle: URL,
        launch: (Process) throws -> Void = { try $0.run() },
        terminate: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        let currentBundle = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent(
            "daemon-swap-\(UUID().uuidString).sh")
        let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            OLD="\(currentBundle.path).old-$$"
            if mv "\(currentBundle.path)" "$OLD"; then
              if mv "\(newAppBundle.path)" "\(currentBundle.path)"; then
                rm -rf "$OLD"
              else
                mv "$OLD" "\(currentBundle.path)"
              fi
            else
              rm -rf "\(currentBundle.path)"
              mv "\(newAppBundle.path)" "\(currentBundle.path)"
            fi
            open "\(currentBundle.path)"
            rm -f "\(scriptPath.path)"
            """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath.path]
        switch Result(catching: {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath.path)
            try launch(task)
        }) {
        case .success:
            DispatchQueue.main.async {
                if !DaemonLifecycle.shared.commitUpdate(terminate) {
                    if task.isRunning { task.terminate() }
                    try? FileManager.default.removeItem(at: scriptPath)
                    DaemonLifecycle.shared.releaseUpdate()
                }
            }
        case .failure(let error):
            try? FileManager.default.removeItem(at: scriptPath)
            DaemonLifecycle.shared.releaseUpdate()
            NSLog("[DaemonUpdater] update handoff failed: \(error.localizedDescription)")
        }
    }
}

struct ReleaseInfo {
    let version: String
    let assetURL: URL?
}
