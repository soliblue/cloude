import Foundation

extension App {
    func handleGitDeepLink(host: String, url: URL) {
        switch host {
        case "git":
            dismissTransientUI()
            if url.path == "/diff",
               let file = url.queryValue(named: "file") {
                openGitDiff(
                    repoPath: url.queryValue(named: "repo") ?? url.queryValue(named: "path"),
                    filePath: file,
                    staged: url.boolQueryValue(named: "staged") ?? false
                )
            } else {
                openGitTab(path: url.queryValue(named: "path"))
            }
        default:
            break
        }
    }
}
