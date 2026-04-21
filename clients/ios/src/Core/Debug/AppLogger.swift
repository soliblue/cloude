import Foundation
import OSLog

enum AppLogger {
    static let bootstrap = Logger(subsystem: "soli.Cloude", category: "Bootstrap")
    static let connection = Logger(subsystem: "soli.Cloude", category: "Connection")
    static let performance = Logger(subsystem: "soli.Cloude", category: "Performance")
    static let ui = Logger(subsystem: "soli.Cloude", category: "UI")

    static let logFileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("app-debug.log")

    private static let writeQueue = DispatchQueue(label: "soli.Cloude.AppLogger")
    private static let intervalLock = NSLock()
    nonisolated(unsafe) private static var intervalStarts: [String: Date] = [:]

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

    static func uiInfo(_ message: String) {
        ui.info("\(message, privacy: .public)")
        append(category: "UI", level: "INFO", message: message)
    }

    static func beginInterval(_ name: String, key: String? = nil, details: String? = nil) {
        let compositeKey = "\(name)|\(key ?? "-")"
        intervalLock.lock()
        intervalStarts[compositeKey] = Date()
        intervalLock.unlock()
        let suffix = details.map { " \($0)" } ?? ""
        performanceInfo("start name=\(name) key=\(key ?? "-")\(suffix)")
    }

    static func endInterval(_ name: String, key: String? = nil, details: String? = nil) {
        let compositeKey = "\(name)|\(key ?? "-")"
        intervalLock.lock()
        let start = intervalStarts.removeValue(forKey: compositeKey)
        intervalLock.unlock()
        if let start {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let suffix = details.map { " \($0)" } ?? ""
            performanceInfo(
                "finish name=\(name) key=\(key ?? "-") durationMs=\(durationMs)\(suffix)")
        }
    }

    private static func append(category: String, level: String, message: String) {
        let line =
            "\(timestampFormatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
        let data = Data(line.utf8)
        let url = logFileURL
        writeQueue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
