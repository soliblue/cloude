import Foundation
import SwiftUI

enum PerfCounters {
    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var inits: [String: Int] = [:]
    nonisolated(unsafe) private static var recentHashes: [Int: Date] = [:]
    nonisolated(unsafe) private static var tickerStarted = false
    private static let lock = NSLock()
    private static let dupWindow: TimeInterval = 2.0

    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: StorageKey.debugOverlayEnabled)
    }

    static func bump(_ name: String) {
        if !enabled { return }
        ensureTicker()
        lock.lock()
        counts[name, default: 0] += 1
        lock.unlock()
    }

    static func bumpInit(_ name: String) {
        if !enabled { return }
        ensureTicker()
        lock.lock()
        inits[name, default: 0] += 1
        lock.unlock()
    }

    static func event(_ message: String) {
        if !enabled { return }
        AppLogger.performanceInfo("perf event \(message)")
    }

    static func bumpParse(hash: Int) {
        if !enabled { return }
        ensureTicker()
        let now = Date()
        lock.lock()
        counts["md.parse", default: 0] += 1
        if let last = recentHashes[hash], now.timeIntervalSince(last) < dupWindow {
            counts["md.parseDup", default: 0] += 1
        }
        recentHashes[hash] = now
        if recentHashes.count > 128 {
            recentHashes = recentHashes.filter { now.timeIntervalSince($0.value) < 10 }
        }
        lock.unlock()
    }

    private static func ensureTicker() {
        lock.lock()
        let start = !tickerStarted
        if start { tickerStarted = true }
        lock.unlock()
        if start {
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    emitTick()
                }
            }
        }
    }

    private static func emitTick() {
        lock.lock()
        let countsSnap = counts
        let initsSnap = inits
        counts.removeAll(keepingCapacity: true)
        inits.removeAll(keepingCapacity: true)
        lock.unlock()

        var all: [String: Int] = countsSnap
        for (k, v) in initsSnap { all["\(k).init"] = v }
        if all.isEmpty { return }
        let parts = all.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        AppLogger.performanceInfo("perf tick \(parts)")
    }
}

extension View {
    func perfTrace(_ name: String) -> some View {
        PerfCounters.bump(name)
        return self
    }
}
