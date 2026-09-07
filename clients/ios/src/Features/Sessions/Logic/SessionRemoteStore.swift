import Foundation
import Observation

@Observable
final class SessionRemoteStore {
    var generation = UUID()
    var requestKey: String?
    var threads: [SessionRemoteThread] = []
    var nextCursor: String?
    var isLoading = false
    var error: String?
    var openingId: String?
    var openingScope: UUID?
}
