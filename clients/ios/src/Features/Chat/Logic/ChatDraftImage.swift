import Foundation

nonisolated struct ChatDraftImage: Equatable, Sendable {
    var id: UUID = UUID()
    var data: Data
}
