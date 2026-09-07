import Foundation

enum DaemonUpdateVersionCompare {
    nonisolated static func isOlder(_ candidate: String, than reference: String) -> Bool {
        if let a = parts(candidate), let b = parts(reference) {
            return (a + Array(repeating: 0, count: 4 - a.count)).lexicographicallyPrecedes(
                b + Array(repeating: 0, count: 4 - b.count))
        }
        return false
    }

    nonisolated static func parts(_ version: String) -> [Int]? {
        let values = version.split(separator: ".", omittingEmptySubsequences: false)
        if (3...4).contains(values.count),
            values.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
            values.compactMap({ Int($0) }).count == values.count
        {
            return values.compactMap { Int($0) }
        }
        return nil
    }
}
