import Foundation

@main
struct DaemonUpdaterTests {
    static func main() {
        precondition(DaemonVersionCompare.isNewer("2026.9.7.10", than: "2026.9.7.9"))
        precondition(DaemonVersionCompare.isNewer("2026.9.7", than: "2026.9.6.99"))
        precondition(!DaemonVersionCompare.isNewer("2026.9.7", than: "2026.9.7.0"))
        precondition(!DaemonVersionCompare.isNewer("2026.9.bad", than: "2026.9.1"))
        precondition(!DaemonVersionCompare.isNewer("2026.9.7", than: "dev"))
        precondition(!DaemonVersionCompare.isValid("1.2"))
        precondition(!DaemonVersionCompare.isValid("1.2.3.4.5"))
        let releases: [[String: Any]] = [
            [
                "tag_name": "macos-daemon-v2026.9.7.99", "draft": true, "prerelease": false,
                "assets": [
                    [
                        "name": DaemonUpdater.assetName,
                        "browser_download_url": "https://github.com/soliblue/cloude/releases/download/a/a.zip",
                    ]
                ],
            ],
            [
                "tag_name": "macos-daemon-v2026.9.8.1", "draft": false, "prerelease": true,
                "assets": [
                    [
                        "name": DaemonUpdater.assetName,
                        "browser_download_url": "https://github.com/soliblue/cloude/releases/download/b/b.zip",
                    ]
                ],
            ],
            [
                "tag_name": "macos-daemon-v2026.9.8", "draft": false, "prerelease": false,
                "assets": [
                    ["name": DaemonUpdater.assetName, "browser_download_url": "http://example.invalid/update.zip"]
                ],
            ],
            ["tag_name": "macos-daemon-v2026.bad.1", "draft": false, "prerelease": false, "assets": []],
            [
                "tag_name": "macos-daemon-v2026.9.7", "draft": false, "prerelease": false,
                "assets": [
                    [
                        "name": DaemonUpdater.assetName,
                        "browser_download_url": "https://github.com/soliblue/cloude/releases/download/c/c.zip",
                    ]
                ],
            ],
            [
                "tag_name": "macos-daemon-v2026.9.7.1", "draft": false, "prerelease": false,
                "assets": [
                    [
                        "name": DaemonUpdater.assetName,
                        "browser_download_url": "https://github.com/soliblue/cloude/releases/download/d/d.zip",
                    ]
                ],
            ],
        ]
        let selected = DaemonUpdater.selectRelease(releases)
        precondition(selected?.version == "2026.9.7.1")
        precondition(selected?.assetURL?.host == "github.com")
        precondition(DaemonLifecycle.shared.reserveUpdate())
        DaemonUpdater.installAndRelaunch(
            newAppBundle: URL(fileURLWithPath: "/tmp/afto-fixture.app"),
            launch: { _ in throw NSError(domain: "Fixture", code: 1) })
        let recovered = DaemonLifecycle.shared.begin()!
        DaemonLifecycle.shared.end(recovered)
        precondition(DaemonLifecycle.shared.reserveUpdate())
        var terminated = false
        var scriptPaths: [String] = []
        DaemonUpdater.installAndRelaunch(
            newAppBundle: URL(fileURLWithPath: "/tmp/afto-fixture.app"),
            launch: { scriptPaths.append($0.arguments![0]) },
            terminate: { terminated = true })
        let arrived = DaemonLifecycle.shared.observeWork()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        precondition(!terminated)
        DaemonLifecycle.shared.end(arrived)
        precondition(DaemonLifecycle.shared.reserveUpdate())
        DaemonUpdater.installAndRelaunch(
            newAppBundle: URL(fileURLWithPath: "/tmp/afto-fixture.app"),
            launch: { scriptPaths.append($0.arguments![0]) },
            terminate: { terminated = true })
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        precondition(terminated)
        precondition(DaemonLifecycle.shared.begin() == nil)
        DaemonLifecycle.shared.releaseUpdate()
        for scriptPath in scriptPaths { try? FileManager.default.removeItem(atPath: scriptPath) }
        print(
            "Daemon updater: numeric versions, release filtering, failed handoff recovery, arriving-work cancellation and reserved termination passed"
        )
    }
}
