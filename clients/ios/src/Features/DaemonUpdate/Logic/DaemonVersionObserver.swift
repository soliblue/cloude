import Foundation
import SwiftData

@MainActor
final class DaemonVersionObserver {
    static let shared = DaemonVersionObserver()
    private var notifiedEndpoints: Set<UUID> = []
    var modelContext: ModelContext?

    nonisolated func observe(response: HTTPURLResponse, endpointId: UUID) {
        let version = response.value(forHTTPHeaderField: "X-Daemon-Version")
        let platform = response.value(forHTTPHeaderField: "X-Daemon-Platform")
        if let version {
            Task { @MainActor in
                self.persist(endpointId: endpointId, version: version, platform: platform)
                if DaemonUpdate.isStale(version: version), !self.notifiedEndpoints.contains(endpointId) {
                    self.notifiedEndpoints.insert(endpointId)
                    SessionToastStore.shared.present(
                        SessionToast(
                            kind: .daemonUpdate(endpointId: endpointId),
                            title: "Daemon update needed",
                            symbol: "arrow.down.circle.fill",
                            snippet: "Tap to install the latest \(platform == "linux" ? "Linux" : "Mac") daemon."
                        )
                    )
                }
            }
        }
    }

    private func persist(endpointId: UUID, version: String, platform: String?) {
        if let context = modelContext {
            let descriptor = FetchDescriptor<Endpoint>(
                predicate: #Predicate<Endpoint> { $0.id == endpointId }
            )
            if let endpoint = try? context.fetch(descriptor).first {
                endpoint.daemonVersion = version
                endpoint.daemonPlatform = platform
                try? context.save()
            }
        }
    }
}
