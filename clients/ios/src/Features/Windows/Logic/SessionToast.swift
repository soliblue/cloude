import Foundation

struct SessionToast: Identifiable, Equatable {
    let id = UUID()
    let sessionId: UUID
    let title: String
    let symbol: String
    let snippet: String
}
