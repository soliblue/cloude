import Foundation

enum DaemonVersionCompare {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let candidateParts = parts(candidate), let currentParts = parts(current) else { return false }
        let width = max(candidateParts.count, currentParts.count)
        let candidate = candidateParts + Array(repeating: 0, count: width - candidateParts.count)
        let current = currentParts + Array(repeating: 0, count: width - currentParts.count)
        return candidate.lexicographicallyPrecedes(current) == false && candidate != current
    }

    static func isValid(_ version: String) -> Bool { parts(version) != nil }

    private static func parts(_ version: String) -> [Int]? {
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (3...4).contains(components.count), components.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        let values = components.compactMap { Int($0) }
        return values.count == components.count ? values : nil
    }
}
