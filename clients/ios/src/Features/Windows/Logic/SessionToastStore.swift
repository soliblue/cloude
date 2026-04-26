import Foundation

@Observable
final class SessionToastStore {
    @MainActor static let shared = SessionToastStore()

    var current: SessionToast?
    private var dismissTask: Task<Void, Never>?

    @MainActor
    func present(_ toast: SessionToast) {
        current = toast
        dismissTask?.cancel()
        let presentedId = toast.id
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            if self.current?.id == presentedId { self.current = nil }
        }
    }

    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
