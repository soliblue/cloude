import Foundation
import CloudeShared

struct MemoryService {
    static func parseMemories() -> [MemorySection] {
        let claudeMdPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/CODING/cloude/CLAUDE.md").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("CLAUDE.md").path
        ]

        var content: String?
        for path in claudeMdPaths {
            if let data = FileManager.default.contents(atPath: path),
               let text = String(data: data, encoding: .utf8) {
                content = text
                Log.info("Found CLAUDE.md at \(path)")
                break
            }
        }

        guard let fileContent = content else {
            Log.error("CLAUDE.md not found")
            return []
        }

        return extractMemorySections(from: fileContent)
    }

    private static func extractMemorySections(from content: String) -> [MemorySection] {
        let memoryMarker = "## Claude's Memory"
        guard let memoryStart = content.range(of: memoryMarker) else {
            Log.error("Claude's Memory section not found")
            return []
        }

        let memoryContent = String(content[memoryStart.upperBound...])

        var sections: [MemorySection] = []
        let lines = memoryContent.components(separatedBy: "\n")
        var currentTitle: String?
        var currentContent: [String] = []

        for line in lines {
            if line.hasPrefix("### ") {
                if let title = currentTitle, !currentContent.isEmpty {
                    let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        sections.append(MemorySection(title: title, content: content))
                    }
                }
                currentTitle = String(line.dropFirst(4))
                currentContent = []
            } else if line.hasPrefix("## ") && currentTitle != nil {
                break
            } else if currentTitle != nil {
                currentContent.append(line)
            }
        }

        if let title = currentTitle, !currentContent.isEmpty {
            let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                sections.append(MemorySection(title: title, content: content))
            }
        }

        Log.info("Parsed \(sections.count) memory sections")
        return sections
    }
}
