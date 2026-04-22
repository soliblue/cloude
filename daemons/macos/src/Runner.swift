import Foundation
import Network

final class Runner {
    let sessionId: String
    private(set) var hasExited = false
    private let hasStartedBefore: Bool
    private let model: String?
    private let effort: String?
    private let queue: DispatchQueue
    var onFinish: (() -> Void)?
    private var process: Process?
    private var stdinPipe: Pipe?
    private var ring: [(seq: Int, data: Data)] = []
    private var subscribers: [NWConnection] = []
    private var seq = 0
    private let maxRingSize = 1000
    private var lineBuffer = Data()

    init(sessionId: String, hasStartedBefore: Bool, model: String?, effort: String?, queue: DispatchQueue) {
        self.sessionId = sessionId
        self.hasStartedBefore = hasStartedBefore
        self.model = model
        self.effort = effort
        self.queue = queue
    }

    func spawn(path: String, prompt: String) {
        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        let executable = Runner.claudeExecutable()
        proc.executableURL = URL(fileURLWithPath: executable.path)
        var claudeArgs =
            executable.leadingArguments + [
                "-p",
                "--output-format", "stream-json",
                "--verbose",
                "--include-partial-messages",
                "--disallowedTools", "AskUserQuestion ExitPlanMode EnterPlanMode",
            ]
        if let model {
            claudeArgs.append(contentsOf: ["--model", model])
        }
        if let effort {
            claudeArgs.append(contentsOf: ["--effort", effort])
        }
        let normalizedId = sessionId.lowercased()
        if hasStartedBefore {
            claudeArgs.append(contentsOf: ["--resume", normalizedId])
        } else {
            claudeArgs.append(contentsOf: ["--session-id", normalizedId])
        }
        proc.arguments = claudeArgs
        proc.currentDirectoryURL = URL(fileURLWithPath: path)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        proc.environment = Runner.spawnEnvironment()

        #if DEBUG
        NSLog(
            "[Runner] spawn sessionId=\(sessionId) hasStartedBefore=\(hasStartedBefore) promptChars=\(prompt.count) executable=\(executable.path)"
        )
        #endif

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self?.queue.async { self?.ingest(data) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            #if DEBUG
            let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count)>"
            NSLog("[Runner] stderr sessionId=\(self?.sessionId ?? "?"): \(text)")
            #endif
        }

        proc.terminationHandler = { [weak self] p in
            self?.queue.async { self?.finish(exitCode: p.terminationStatus) }
        }

        do {
            try proc.run()
            self.process = proc
            self.stdinPipe = stdin
            stdin.fileHandleForWriting.write(Data(prompt.utf8))
            try? stdin.fileHandleForWriting.close()
        } catch {
            #if DEBUG
            NSLog("[Runner] spawn_failed sessionId=\(sessionId) error=\(error)")
            #endif
            emit(["type": "error", "message": "spawn_failed: \(error.localizedDescription)"])
            finish(exitCode: -1)
        }
    }

    func subscribe(_ connection: NWConnection, afterSeq: Int = -1) {
        #if DEBUG
        NSLog(
            "[Runner] subscribe sessionId=\(sessionId) afterSeq=\(afterSeq) ringSize=\(ring.count) hasExited=\(hasExited)"
        )
        #endif
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async { self?.removeSubscriber(connection) }
            default: break
            }
        }
        var batch = Data()
        for (s, data) in ring where s > afterSeq { batch.append(data) }
        if !batch.isEmpty {
            connection.send(content: batch, completion: .contentProcessed { _ in })
        }
        if hasExited {
            connection.cancel()
        } else {
            subscribers.append(connection)
        }
    }

    func abort() {
        if let proc = process, proc.isRunning {
            emit(["type": "aborted"])
            proc.interrupt()
        }
    }

    private func removeSubscriber(_ connection: NWConnection?) {
        if let connection = connection {
            subscribers.removeAll { $0 === connection }
        }
    }

    private func ingest(_ data: Data) {
        lineBuffer.append(data)
        while let nl = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer.subdata(in: 0..<nl)
            lineBuffer.removeSubrange(0...nl)
            if line.isEmpty { continue }
            if let obj = try? JSONSerialization.jsonObject(with: line) {
                emit(["event": obj])
            } else {
                #if DEBUG
                let text = String(data: line, encoding: .utf8) ?? "<binary \(line.count)>"
                NSLog("[Runner] stdout non-json sessionId=\(sessionId): \(text)")
                #endif
            }
        }
    }

    private func emit(_ partial: [String: Any]) {
        seq += 1
        var wrapped = partial
        wrapped["seq"] = seq
        wrapped["sessionId"] = sessionId
        if let payload = try? JSONSerialization.data(withJSONObject: wrapped) {
            var chunk = payload
            chunk.append(0x0A)
            ring.append((seq, chunk))
            if ring.count > maxRingSize { ring.removeFirst(ring.count - maxRingSize) }
            for sub in subscribers {
                sub.send(content: chunk, completion: .contentProcessed { _ in })
            }
        }
    }

    private func finish(exitCode: Int32) {
        if hasExited { return }
        hasExited = true
        if let stderrPipe = process?.standardError as? Pipe {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
            #if DEBUG
            let text = String(data: remaining, encoding: .utf8) ?? "<binary \(remaining.count)>"
            NSLog("[Runner] stderr (drained) sessionId=\(sessionId) bytes=\(remaining.count): \(text)")
            #endif
        }
        if let stdoutPipe = process?.standardOutput as? Pipe {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
            #if DEBUG
            let text = String(data: remaining, encoding: .utf8) ?? "<binary \(remaining.count)>"
            NSLog("[Runner] stdout (drained) sessionId=\(sessionId) bytes=\(remaining.count): \(text)")
            #endif
        }
        #if DEBUG
        NSLog(
            "[Runner] finish sessionId=\(sessionId) exitCode=\(exitCode) ringSize=\(ring.count) subscribers=\(subscribers.count)"
        )
        #endif
        emit(["type": "exit", "code": Int(exitCode)])
        for sub in subscribers { sub.cancel() }
        subscribers.removeAll()
        process?.standardOutput.flatMap { ($0 as? Pipe) }?.fileHandleForReading.readabilityHandler = nil
        onFinish?()
    }

    private static func spawnEnvironment() -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in ["HOME", "USER", "SHELL", "LANG", "LC_ALL", "TMPDIR", "TERM"] {
            if let value = inherited[key] { env[key] = value }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var pathParts = (inherited["PATH"] ?? "").split(separator: ":").map(String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !pathParts.contains(extra) {
            pathParts.append(extra)
        }
        env["PATH"] = pathParts.joined(separator: ":")
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        env["NO_COLOR"] = "1"
        env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        return env
    }

    private struct Executable {
        let path: String
        let leadingArguments: [String]
    }

    private static func claudeExecutable() -> Executable {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var directories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(
            String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !directories.contains(extra) {
            directories.append(extra)
        }
        for directory in directories {
            let candidate = "\(directory)/claude"
            if fileManager.isExecutableFile(atPath: candidate) {
                return Executable(path: candidate, leadingArguments: [])
            }
        }
        return Executable(path: "/usr/bin/env", leadingArguments: ["claude"])
    }
}
