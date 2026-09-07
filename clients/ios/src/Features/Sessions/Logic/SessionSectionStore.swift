import Foundation
import Observation

@MainActor @Observable final class SessionSectionStore {
    var sections: [SessionSection] = []
    var nextCursor: String?
    var isLoading = false
    var isMutating = false
    var error: String?
    var scope: UUID?
    var generation = UUID()

    static func validName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf16.count <= 120 && !name.contains("\0")
    }
}
