import Foundation

@MainActor
final class GitStatusService {
    var send: ((String) -> Void)?
    var canSend: () -> Bool = { true }

    private var queue: [String] = []
    private(set) var inFlightPath: String?
    private var timeoutTask: Task<Void, Never>?

    func enqueue(_ path: String) {
        if inFlightPath != path && !queue.contains(path) {
            queue.append(path)
        }
        sendNextIfReady()
    }

    func completeInFlight() -> String? {
        let path = inFlightPath
        clearInFlight()
        sendNextIfReady()
        return path
    }

    func cancelInFlight() {
        clearInFlight()
    }

    func reset() {
        queue.removeAll()
        clearInFlight()
    }

    func sendNextIfReady() {
        if canSend(), inFlightPath == nil, !queue.isEmpty {
            let next = queue.removeFirst()
            inFlightPath = next
            send?(next)
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                if let self, !Task.isCancelled, self.inFlightPath == next {
                    self.inFlightPath = nil
                    self.sendNextIfReady()
                }
            }
        }
    }

    private func clearInFlight() {
        timeoutTask?.cancel()
        timeoutTask = nil
        inFlightPath = nil
    }
}
