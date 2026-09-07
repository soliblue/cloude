import Foundation
import Network

final class CodexTerminalStream {
    private let connection: NWConnection
    private let terminalId: String
    private let subscriberId = UUID().uuidString
    private let queue = DispatchQueue(label: "soli.Cloude.codex.terminal-stream")
    private var buffered: [Data] = []
    private var bytes = 0
    private var sending = false
    private var ending = false
    private var closed = false
    private var heartbeat: DispatchSourceTimer?

    init(connection: NWConnection, terminalId: String) {
        self.connection = connection
        self.terminalId = terminalId
    }

    func start(sessionId: String, cursor: Int) {
        CodexTerminal.shared.subscribe(
            sessionId: sessionId, terminalId: terminalId, cursor: cursor, subscriberId: subscriberId
        ) { event, ended in
            self.queue.async {
                if !self.closed {
                    if let event, var data = try? JSONSerialization.data(withJSONObject: event) {
                        data.append(0x0A)
                        self.buffered.append(data)
                        self.bytes += data.count
                    }
                    self.ending = self.ending || ended
                    if self.bytes > 2_097_152 { self.close() } else { self.flush() }
                }
            }
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, _, _ in
            self?.queue.async { self?.close() }
        }
        queue.async {
            if self.closed { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 15, repeating: 15)
            timer.setEventHandler { [weak self] in
                if let self, !self.closed, !self.ending {
                    self.buffered.append(Data([0x0A]))
                    self.bytes += 1
                    if self.bytes > 2_097_152 { self.close() } else { self.flush() }
                }
            }
            self.heartbeat = timer
            timer.resume()
        }
    }

    private func flush() {
        if !closed, !sending {
            if !buffered.isEmpty {
                sending = true
                let data = buffered.removeFirst()
                connection.send(
                    content: data,
                    completion: .contentProcessed { error in
                        self.queue.async {
                            self.bytes -= data.count
                            self.sending = false
                            if error != nil { self.close() } else { self.flush() }
                        }
                    })
            } else if ending {
                close()
            }
        }
    }

    private func close() {
        if !closed {
            closed = true
            heartbeat?.cancel()
            heartbeat = nil
            buffered.removeAll()
            CodexTerminal.shared.unsubscribe(terminalId: terminalId, subscriberId: subscriberId)
            connection.cancel()
        }
    }
}
