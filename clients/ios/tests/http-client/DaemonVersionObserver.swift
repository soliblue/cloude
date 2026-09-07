import Foundation

@MainActor final class DaemonVersionObserver {
    static let shared = DaemonVersionObserver()
    var observed: [UUID] = []
    func observe(response: HTTPURLResponse, endpointId: UUID) { observed.append(endpointId) }
}
