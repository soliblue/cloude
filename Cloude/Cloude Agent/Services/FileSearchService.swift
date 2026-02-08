import Foundation
import CloudeShared

struct FileSearchService {
    static func search(query: String, in directory: String, maxResults: Int = 20) -> [String] {
        let gitignorePatterns = loadGitignore(in: directory)
        let fileManager = FileManager.default

        if query.isEmpty {
            return recentFiles(in: directory, patterns: gitignorePatterns, max: maxResults)
        }

        var results: [String] = []
        let lowercaseQuery = query.lowercased()

        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            guard results.count < maxResults else { break }

            let relativePath = url.path.replacingOccurrences(of: directory + "/", with: "")

            if shouldIgnore(path: relativePath, patterns: gitignorePatterns) {
                if url.hasDirectoryPath {
                    enumerator?.skipDescendants()
                }
                continue
            }

            guard !url.hasDirectoryPath else { continue }

            let filename = url.lastPathComponent.lowercased()
            if filename.contains(lowercaseQuery) {
                results.append(url.path)
            }
        }

        return results.sorted { a, b in
            let aName = a.lastPathComponent.lowercased()
            let bName = b.lastPathComponent.lowercased()
            let aExact = aName == lowercaseQuery
            let bExact = bName == lowercaseQuery
            if aExact != bExact { return aExact }
            let aStarts = aName.hasPrefix(lowercaseQuery)
            let bStarts = bName.hasPrefix(lowercaseQuery)
            if aStarts != bStarts { return aStarts }
            return a.count < b.count
        }
    }

    private static func recentFiles(in directory: String, patterns: [String], max: Int) -> [String] {
        let fileManager = FileManager.default
        var files: [(path: String, modified: Date)] = []

        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            let relativePath = url.path.replacingOccurrences(of: directory + "/", with: "")

            if shouldIgnore(path: relativePath, patterns: patterns) {
                if url.hasDirectoryPath {
                    enumerator?.skipDescendants()
                }
                continue
            }

            guard !url.hasDirectoryPath else { continue }

            if let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                files.append((url.path, modDate))
            }
        }

        return files
            .sorted { $0.modified > $1.modified }
            .prefix(max)
            .map(\.path)
    }

    private static func loadGitignore(in directory: String) -> [String] {
        let gitignorePath = directory.appendingPathComponent(".gitignore")
        guard let content = try? String(contentsOfFile: gitignorePath, encoding: .utf8) else {
            return defaultIgnorePatterns
        }

        var patterns = defaultIgnorePatterns
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                patterns.append(trimmed)
            }
        }
        return patterns
    }

    private static let defaultIgnorePatterns = [
        ".git", "node_modules", ".build", "DerivedData", "Pods",
        ".venv", "venv", "__pycache__", ".cache", "dist", "build"
    ]

    private static func shouldIgnore(path: String, patterns: [String]) -> Bool {
        let components = path.components(separatedBy: "/")

        for pattern in patterns {
            let cleanPattern = pattern.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            if components.contains(cleanPattern) {
                return true
            }

            if pattern.hasSuffix("/") && components.contains(String(pattern.dropLast())) {
                return true
            }

            if cleanPattern.contains("*") {
                let regex = cleanPattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")
                if let _ = path.range(of: "^" + regex + "$", options: .regularExpression) {
                    return true
                }
            }
        }

        return false
    }
}
