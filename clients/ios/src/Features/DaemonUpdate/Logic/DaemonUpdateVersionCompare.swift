import Foundation

enum DaemonUpdateVersionCompare {
    static func isOlder(_ candidate: String, than reference: String) -> Bool {
        let a = parts(candidate)
        let b = parts(reference)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return true }
            if x > y { return false }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
