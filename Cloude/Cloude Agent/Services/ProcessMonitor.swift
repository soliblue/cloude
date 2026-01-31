import Foundation

struct ClaudeProcess: Identifiable {
    let id: Int32
    let command: String
    let startTime: Date?
    let parentPid: Int32
}

class ProcessMonitor {
    static func findClaudeProcesses() -> [ClaudeProcess] {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,ppid,lstart,command"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let myPid = ProcessInfo.processInfo.processIdentifier
        var results: [ClaudeProcess] = []

        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard trimmed.contains("claude") || trimmed.contains("Claude") else { continue }

            guard !trimmed.contains("Cloude Agent") && !trimmed.contains("Cloude-Agent") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2,
                  let pid = Int32(parts[0]) else { continue }

            let remainder = String(parts[1])
            let remainderParts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard remainderParts.count >= 2,
                  let ppid = Int32(remainderParts[0]) else { continue }

            let afterPpid = String(remainderParts[1])

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"

            var startTime: Date? = nil
            var command = afterPpid

            if afterPpid.count > 24 {
                let dateStr = String(afterPpid.prefix(24))
                startTime = dateFormatter.date(from: dateStr)
                if startTime != nil {
                    command = String(afterPpid.dropFirst(24)).trimmingCharacters(in: .whitespaces)
                }
            }

            if pid == myPid { continue }

            results.append(ClaudeProcess(
                id: pid,
                command: command,
                startTime: startTime,
                parentPid: ppid
            ))
        }

        return results
    }

    static func killProcess(_ pid: Int32) -> Bool {
        kill(pid, SIGTERM)

        usleep(100_000)

        let checkResult = kill(pid, 0)
        if checkResult == 0 {
            kill(pid, SIGKILL)
        }

        return true
    }

    static func killAllClaudeProcesses() -> Int {
        let processes = findClaudeProcesses()
        var killed = 0

        for proc in processes {
            if killProcess(proc.id) {
                killed += 1
            }
        }

        return killed
    }

    static func findOtherAgentProcesses() -> [ClaudeProcess] {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,ppid,lstart,command"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let myPid = ProcessInfo.processInfo.processIdentifier
        var results: [ClaudeProcess] = []

        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard trimmed.contains("Cloude Agent") || trimmed.contains("Cloude-Agent") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2,
                  let pid = Int32(parts[0]) else { continue }

            if pid == myPid { continue }

            let remainder = String(parts[1])
            let remainderParts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard remainderParts.count >= 2,
                  let ppid = Int32(remainderParts[0]) else { continue }

            let afterPpid = String(remainderParts[1])

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"

            var startTime: Date? = nil
            var command = afterPpid

            if afterPpid.count > 24 {
                let dateStr = String(afterPpid.prefix(24))
                startTime = dateFormatter.date(from: dateStr)
                if startTime != nil {
                    command = String(afterPpid.dropFirst(24)).trimmingCharacters(in: .whitespaces)
                }
            }

            results.append(ClaudeProcess(
                id: pid,
                command: command,
                startTime: startTime,
                parentPid: ppid
            ))
        }

        return results
    }

    static func killOtherAgents() -> Int {
        let processes = findOtherAgentProcesses()
        var killed = 0

        for proc in processes {
            Log.info("Killing other agent process: \(proc.id)")
            if killProcess(proc.id) {
                killed += 1
            }
        }

        return killed
    }
}
