import Foundation
import CloudeShared

struct MemoryService {
    private static let sourceFile = #file

    static var projectRoot: String {
        if let dir = HeartbeatService.shared.projectDirectory {
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

    static func parseMemories() -> [MemorySection] {
        let path = (projectRoot as NSString).appendingPathComponent("CLAUDE.local.md")

        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            Log.error("CLAUDE.local.md not found at \(path)")
            return []
        }

        Log.info("Found CLAUDE.local.md at \(path)")
        return extractMemorySections(from: text)
    }

    private static func extractMemorySections(from content: String) -> [MemorySection] {
        var sections: [MemorySection] = []
        let lines = content.components(separatedBy: "\n")
        var currentTitle: String?
        var currentContent: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                if let title = currentTitle, !currentContent.isEmpty {
                    let sectionContent = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sectionContent.isEmpty {
                        sections.append(MemorySection(title: title, content: sectionContent))
                    }
                }
                currentTitle = String(line.dropFirst(3))
                currentContent = []
            } else if currentTitle != nil && !line.hasPrefix("# ") {
                currentContent.append(line)
            }
        }

        if let title = currentTitle, !currentContent.isEmpty {
            let sectionContent = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sectionContent.isEmpty {
                sections.append(MemorySection(title: title, content: sectionContent))
            }
        }

        Log.info("Parsed \(sections.count) memory sections")
        return sections
    }
}
