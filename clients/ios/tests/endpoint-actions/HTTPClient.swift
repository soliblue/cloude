import Foundation

enum HTTPClient {
    static var invalidated: [UUID] = []
    static func invalidate(endpointId: UUID) { invalidated.append(endpointId) }
}
