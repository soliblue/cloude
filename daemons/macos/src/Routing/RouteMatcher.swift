import Foundation

enum RouteMatcher {
    static func split(_ rawPath: String) -> (path: String, query: [String: String]) {
        if let markIndex = rawPath.firstIndex(of: "?") {
            return (
                String(rawPath[..<markIndex]),
                parseQuery(String(rawPath[rawPath.index(after: markIndex)...]))
            )
        }
        return (rawPath, [:])
    }

    static func match(_ path: String, pattern: String) -> [String: String]? {
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true)
        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: true)
        if pathParts.count == patternParts.count {
            var params: [String: String] = [:]
            for (p, pat) in zip(pathParts, patternParts) {
                if pat.hasPrefix(":") {
                    params[String(pat.dropFirst())] = String(p)
                } else if p != pat {
                    return nil
                }
            }
            return params
        }
        return nil
    }

    private static func parseQuery(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            if let eq = pair.firstIndex(of: "=") {
                let key = String(pair[..<eq]).removingPercentEncoding ?? String(pair[..<eq])
                let valueRaw = pair[pair.index(after: eq)...]
                result[key] = String(valueRaw).removingPercentEncoding ?? String(valueRaw)
            }
        }
        return result
    }
}
