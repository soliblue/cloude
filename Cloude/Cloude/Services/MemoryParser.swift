import Foundation
import CloudeShared

struct MemoryParser {
    static func parse(sections: [MemorySection]) -> [ParsedMemorySection] {
        sections.map { section in
            let items = parseItems(from: section.content)
            return ParsedMemorySection(from: section, items: items)
        }
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
