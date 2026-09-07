import Foundation
import Observation

@MainActor @Observable final class SessionCompactionStore {
    var snapshot: SessionCompactionSnapshot?
    var error: String?
    var isLoading = false
    var isStarting = false
    var uncertainStart = false
    var generation = UUID()
    var scope: String?

    var isPending: Bool { snapshot?.status == "pending" }

    func canStart(session: Session) -> Bool {
        session.provider == .codex && session.existsOnServer && !session.isStreaming && !session.remoteIsRunning
            && session.endpoint?.capabilities?.contains("codexCompaction") == true
            && scope == "\(session.endpoint?.id.uuidString ?? "")|\(session.id)"
            && snapshot != nil && !isPending && !isLoading && !isStarting && !uncertainStart
    }

    func begin(session: Session, starting: Bool) -> UUID? {
        let scope = "\(session.endpoint?.id.uuidString ?? "")|\(session.id)"
        if self.scope != scope {
            invalidate()
            self.scope = scope
            snapshot = nil
            uncertainStart = false
        }
        if !isStarting {
            generation = UUID()
            isLoading = true
            isStarting = starting
            error = nil
            return generation
        }
        return nil
    }

    func invalidate() {
        generation = UUID()
        isLoading = false
        isStarting = false
    }
}
