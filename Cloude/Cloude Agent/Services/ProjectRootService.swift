import Foundation

struct ProjectRootService {
    private static let sourceFile = #file
    static var projectDirectory: String?

    static var projectRoot: String {
        if let dir = projectDirectory {
            return dir
        }
        var url = URL(fileURLWithPath: sourceFile)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("CLAUDE.md").path) {
                return url.path
            }
        }
        return FileManager.default.currentDirectoryPath
    }
}
