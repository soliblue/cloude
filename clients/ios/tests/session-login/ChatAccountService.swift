import Foundation

@MainActor enum ChatAccountService {
    static var refreshed: [UUID] = []
    static func refresh(endpoint: Endpoint) async { refreshed.append(endpoint.id) }
}
