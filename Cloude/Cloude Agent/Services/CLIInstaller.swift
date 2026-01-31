import Foundation
import CloudeShared

enum CLIInstaller {
    static func installIfNeeded() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        let searchPaths = [
            "\(home)/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin"
        ]

        var targetDir: String?
        for path in searchPaths {
            let claudePath = "\(path)/claude"
            if fm.fileExists(atPath: claudePath) {
                targetDir = path
                break
            }
        }

        guard let dir = targetDir else {
            Log.info("Could not find claude CLI, skipping cloude CLI install")
            return
        }

        let targetPath = "\(dir)/cloude"

        if fm.fileExists(atPath: targetPath) {
            return
        }

        let script = "#!/bin/bash\nexit 0\n"
        fm.createFile(atPath: targetPath, contents: script.data(using: .utf8))

        var attributes = [FileAttributeKey: Any]()
        attributes[.posixPermissions] = 0o755
        try? fm.setAttributes(attributes, ofItemAtPath: targetPath)

        Log.info("Installed cloude CLI to \(targetPath)")
    }
}
