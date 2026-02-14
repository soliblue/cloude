import Foundation
import CloudeShared

struct MemoryParser {
    static func parse(sections: [MemorySection]) -> [ParsedMemorySection] {
        sections.map { section in
            parseSection(id: section.id, title: section.title, content: section.content, level: 2)
        }
    }

    private static func parseSection(id: String, title: String, content: String, level: Int) -> ParsedMemorySection {
        let (cleanTitle, icon) = extractIcon(from: title)
        let headerPrefix = String(repeating: "#", count: level + 1) + " "
        let lines = content.components(separatedBy: "\n")

        var topLevelContent: [String] = []
        var subsections: [ParsedMemorySection] = []
        var currentSubsectionTitle: String?
        var currentSubsectionContent: [String] = []

        for line in lines {
            if line.hasPrefix(headerPrefix) {
                if let subsectionTitle = currentSubsectionTitle {
                    let (cleanSubTitle, _) = extractIcon(from: subsectionTitle)
                    let subsectionId = "\(id)/\(cleanSubTitle)"
                    let subsection = parseSection(
                        id: subsectionId,
                        title: subsectionTitle,
                        content: currentSubsectionContent.joined(separator: "\n"),
                        level: level + 1
                    )
                    subsections.append(subsection)
                }

                currentSubsectionTitle = String(line.dropFirst(headerPrefix.count)).trimmingCharacters(in: .whitespaces)
                currentSubsectionContent = []
            } else if currentSubsectionTitle != nil {
                currentSubsectionContent.append(line)
            } else {
                topLevelContent.append(line)
            }
        }

        if let subsectionTitle = currentSubsectionTitle {
            let (cleanSubTitle, _) = extractIcon(from: subsectionTitle)
            let subsectionId = "\(id)/\(cleanSubTitle)"
            let subsection = parseSection(
                id: subsectionId,
                title: subsectionTitle,
                content: currentSubsectionContent.joined(separator: "\n"),
                level: level + 1
            )
            subsections.append(subsection)
        }

        let items = parseItems(from: topLevelContent.joined(separator: "\n"))

        return ParsedMemorySection(
            id: id,
            title: cleanTitle,
            icon: icon,
            items: items,
            subsections: subsections,
            rawContent: content
        )
    }

    private static func extractIcon(from title: String) -> (String, String?) {
        let pattern = "^(.+?)\\s*\\{([a-z0-9.]+)\\}$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            let titleRange = Range(match.range(at: 1), in: title)!
            let iconRange = Range(match.range(at: 2), in: title)!
            let cleanTitle = String(title[titleRange]).trimmingCharacters(in: .whitespaces)
            let icon = String(title[iconRange])
            return (cleanTitle, icon)
        }
        return (title, nil)
    }

    static func parseItems(from content: String) -> [MemoryItem] {
        var items: [MemoryItem] = []
        let lines = content.components(separatedBy: "\n")
        var paragraphBuffer: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                if !paragraphBuffer.isEmpty {
                    let paragraphText = paragraphBuffer.joined(separator: " ")
                    if !paragraphText.isEmpty {
                        items.append(MemoryItem(content: paragraphText, isBullet: false))
                    }
                    paragraphBuffer = []
                }

                let bulletContent = String(trimmed.dropFirst(2))
                let (text, date) = extractTimestamp(from: bulletContent)
                items.append(MemoryItem(content: text, timestamp: date, isBullet: true))
            } else if trimmed.isEmpty {
                if !paragraphBuffer.isEmpty {
                    let paragraphText = paragraphBuffer.joined(separator: " ")
                    if !paragraphText.isEmpty {
                        items.append(MemoryItem(content: paragraphText, isBullet: false))
                    }
                    paragraphBuffer = []
                }
            } else {
                paragraphBuffer.append(trimmed)
            }
        }

        if !paragraphBuffer.isEmpty {
            let paragraphText = paragraphBuffer.joined(separator: " ")
            if !paragraphText.isEmpty {
                items.append(MemoryItem(content: paragraphText, isBullet: false))
            }
        }

        return items
    }

    private static func extractTimestamp(from text: String) -> (String, Date?) {
        let patterns = [
            "^\\*\\*([0-9]{4}-[0-9]{2}-[0-9]{2})\\*\\*:\\s*",
            "^\\*\\*([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2})\\*\\*:\\s*"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let dateRange = Range(match.range(at: 1), in: text)!
                let dateString = String(text[dateRange])
                let fullMatchRange = Range(match.range, in: text)!
                let remainingText = String(text[fullMatchRange.upperBound...])

                var date: Date?
                if dateString.count > 10 {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    date = formatter.date(from: dateString)
                } else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    date = formatter.date(from: dateString)
                }

                return (remainingText, date)
            }
        }

        return (text, nil)
    }
}
