import Foundation
import Observation

@MainActor @Observable final class SessionLoginStore {
    var snapshot: SessionLoginSnapshot?
    var endpointId: UUID?
    var error: String?
    var isLoading = false
    var isMutating = false
    var generation = UUID()

    var isPending: Bool { snapshot?.status == "pending" }
    var completionId: String? { snapshot?.status == "completed" ? snapshot?.loginId ?? "completed" : nil }

    func begin(endpointId: UUID, mutating: Bool) -> UUID? {
        if self.endpointId != endpointId {
            invalidate()
            self.endpointId = endpointId
            snapshot = nil
            error = nil
        }
        if !isMutating {
            generation = UUID()
            isMutating = mutating
            isLoading = true
            error = nil
            return generation
        }
        return nil
    }

    func finish(_ generation: UUID, snapshot: SessionLoginSnapshot?, error: String?) {
        if self.generation == generation {
            if let snapshot { self.snapshot = snapshot }
            self.error = error ?? snapshot?.error
            isLoading = false
            isMutating = false
        }
    }

    func invalidate() {
        generation = UUID()
        isLoading = false
        isMutating = false
    }
}
