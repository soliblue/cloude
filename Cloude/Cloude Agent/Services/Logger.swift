//
//  Logger.swift
//  Cloude Agent
//

import Foundation

struct Log {
    private static let logFile: URL = {
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Cloude")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("agent.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String, file: String = #file, function: String = #function) {
        log("INFO", message, file: file, function: function)
    }

    static func error(_ message: String, file: String = #file, function: String = #function) {
        log("ERROR", message, file: file, function: function)
    }

    static func debug(_ message: String, file: String = #file, function: String = #function) {
        log("DEBUG", message, file: file, function: function)
    }

    private static func log(_ level: String, _ message: String, file: String, function: String) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let line = "[\(timestamp)] [\(level)] [\(filename).\(function)] \(message)\n"

        print(line, terminator: "")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    static var logPath: String { logFile.path }
}
