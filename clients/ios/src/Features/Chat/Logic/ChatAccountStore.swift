import Foundation
import Observation

@Observable
final class ChatAccountStore {
    static let shared = ChatAccountStore()
    var generations: [UUID: UUID] = [:]
    var accounts: [UUID: ChatAccountSnapshot] = [:]
    var loading: Set<UUID> = []
    var errors: [UUID: String] = [:]
}
