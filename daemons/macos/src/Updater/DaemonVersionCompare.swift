import Foundation

enum DaemonVersionCompare {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        if current == "dev" { return false }
        return parts(candidate).lexicographicallyPrecedes(parts(current)) == false
            && parts(candidate) != parts(current)
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
