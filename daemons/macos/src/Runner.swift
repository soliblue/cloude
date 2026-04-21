import Foundation
import Network

final class Runner {
    let sessionId: String
    private(set) var hasExited = false
    private let hasStartedBefore: Bool
    private let queue: DispatchQueue
    var onFinish: (() -> Void)?
    private var process: Process?
    private var stdinPipe: Pipe?
    private var ring: [(seq: Int, data: Data)] = []
    private var subscribers: [NWConnection] = []
    private var seq = 0
    private let maxRingSize = 1000
    private var lineBuffer = Data()

    init(sessionId: String, hasStartedBefore: Bool, queue: DispatchQueue) {
        self.sessionId = sessionId
        self.hasStartedBefore = hasStartedBefore
        self.queue = queue
    }

    func spawn(path: String, prompt: String) {
        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        var claudeArgs = [
            "claude",
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--disallowedTools", "AskUserQuestion ExitPlanMode EnterPlanMode",
        ]
        if hasStartedBefore {
            claudeArgs.append(contentsOf: ["--resume", sessionId])
        } else {
            claudeArgs.append(contentsOf: ["--session-id", sessionId])
        }
        let joined = claudeArgs.map(shellQuote).joined(separator: " ")
        proc.arguments = ["-l", "-c", "cd \(shellQuote(path)) && \(joined)"]
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self?.queue.async { self?.ingest(data) }
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
            emit(["type": "error", "message": "spawn_failed: \(error.localizedDescription)"])
            finish(exitCode: -1)
        }
    }

    func subscribe(_ connection: NWConnection, afterSeq: Int = -1) {
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
        emit(["type": "exit", "code": Int(exitCode)])
        for sub in subscribers { sub.cancel() }
        subscribers.removeAll()
        process?.standardOutput.flatMap { ($0 as? Pipe) }?.fileHandleForReading.readabilityHandler = nil
        onFinish?()
    }

    private func shellQuote(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
