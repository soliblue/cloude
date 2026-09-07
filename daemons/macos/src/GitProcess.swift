import Darwin
import Foundation

enum GitProcess {
    static func run(_ args: [String], cwd: URL) -> (String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = cwd
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        stderr.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        if (try? process.run()) != nil {
            let timeout = DispatchWorkItem { if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
            var output = Data()
            var withinLimit = true
            while let chunk = try? stdout.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
                if output.count + chunk.count <= 10 * 1024 * 1024 {
                    output.append(chunk)
                } else {
                    withinLimit = false
                    Darwin.kill(process.processIdentifier, SIGKILL)
                    break
                }
            }
            try? stdout.fileHandleForReading.close()
            process.waitUntilExit()
            timeout.cancel()
            stderr.fileHandleForReading.readabilityHandler = nil
            return withinLimit && process.terminationReason == .exit
                ? (String(decoding: output, as: UTF8.self), process.terminationStatus) : ("", -1)
        }
        stderr.fileHandleForReading.readabilityHandler = nil
        return ("", -1)
    }
}
