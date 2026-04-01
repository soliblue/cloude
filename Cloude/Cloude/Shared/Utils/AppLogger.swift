import OSLog
import Foundation

enum AppLogger {
    static let bootstrap = Logger(subsystem: "soli.Cloude", category: "Bootstrap")
    static let connection = Logger(subsystem: "soli.Cloude", category: "Connection")
    static let performance = Logger(subsystem: "soli.Cloude", category: "Performance")
    static let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("app-debug.log")
    private static let intervalLock = NSLock()
    private static var intervalStarts: [String: Date] = [:]

    static func bootstrapInfo(_ message: String) {
        bootstrap.info("\(message, privacy: .public)")
        append(category: "Bootstrap", level: "INFO", message: message)
    }

    static func connectionInfo(_ message: String) {
        connection.info("\(message, privacy: .public)")
        append(category: "Connection", level: "INFO", message: message)
    }

    static func connectionError(_ message: String) {
        connection.error("\(message, privacy: .public)")
        append(category: "Connection", level: "ERROR", message: message)
    }

    static func performanceInfo(_ message: String) {
        performance.info("\(message, privacy: .public)")
        append(category: "Performance", level: "INFO", message: message)
    }

    static func beginInterval(_ name: String, key: String? = nil, details: String? = nil) {
        let intervalKey = intervalKey(name: name, key: key)
        intervalLock.lock()
        intervalStarts[intervalKey] = Date()
        intervalLock.unlock()

        let suffix = details.map { " \($0)" } ?? ""
        performanceInfo("start name=\(name) key=\(key ?? "-")\(suffix)")
    }

    static func endInterval(_ name: String, key: String? = nil, details: String? = nil) {
        let intervalKey = intervalKey(name: name, key: key)
        intervalLock.lock()
        let start = intervalStarts.removeValue(forKey: intervalKey)
        intervalLock.unlock()

        guard let start else { return }

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let suffix = details.map { " \($0)" } ?? ""
        performanceInfo("finish name=\(name) key=\(key ?? "-") durationMs=\(durationMs)\(suffix)")
    }

    static func cancelInterval(_ name: String, key: String? = nil, reason: String? = nil) {
        let intervalKey = intervalKey(name: name, key: key)
        intervalLock.lock()
        let removed = intervalStarts.removeValue(forKey: intervalKey)
        intervalLock.unlock()
        guard removed != nil else { return }
        performanceInfo("cancel name=\(name) key=\(key ?? "-") reason=\(reason ?? "unspecified")")
    }

    private static func intervalKey(name: String, key: String?) -> String {
        "\(name)|\(key ?? "-")"
    }

    private static func append(category: String, level: String, message: String) {
        let line = "\(timestampFormatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
        let existing = (try? Data(contentsOf: logFileURL)) ?? Data()
        var updated = existing
        updated.append(Data(line.utf8))
        try? updated.write(to: logFileURL, options: .atomic)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
