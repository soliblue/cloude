import Foundation
import CloudeShared

struct MemoryService {
    private static let sourceFile = #file

    enum MemoryTarget {
        case local
        case project

        var filename: String {
            switch self {
            case .local: return "CLAUDE.local.md"
            case .project: return "CLAUDE.md"
            }
        }
    }

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

    static func addMemory(target: MemoryTarget, section: String, text: String) -> Bool {
        let path = projectRoot.appendingPathComponent(target.filename)

        var content: String
        if let data = FileManager.default.contents(atPath: path),
           let existing = String(data: data, encoding: .utf8) {
            content = existing
        } else {
            content = "# \(target == .local ? "CLAUDE.local.md" : "CLAUDE.md")\n\n"
        }

        let sectionHeader = "## \(section)"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "- **\(timestamp.prefix(10))**: \(text)"

        if let range = content.range(of: sectionHeader) {
            let insertPoint = content.index(range.upperBound, offsetBy: 0)
            let afterHeader = content[insertPoint...]

            if let nextSectionRange = afterHeader.range(of: "\n## ") {
                let insertIndex = content.index(nextSectionRange.lowerBound, offsetBy: 0)
                content.insert(contentsOf: "\n\(entry)\n", at: insertIndex)
            } else {
                if !content.hasSuffix("\n") { content += "\n" }
                content += "\(entry)\n"
            }
        } else {
            if !content.hasSuffix("\n\n") {
                if content.hasSuffix("\n") { content += "\n" }
                else { content += "\n\n" }
            }
            content += "\(sectionHeader)\n\(entry)\n"
        }

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            Log.info("Added memory to \(target.filename) section '\(section)': \(text.prefix(50))...")
            return true
        } catch {
            Log.error("Failed to write memory: \(error)")
            return false
        }
    }

    static func parseMemories() -> [MemorySection] {
        let path = projectRoot.appendingPathComponent("CLAUDE.local.md")

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
