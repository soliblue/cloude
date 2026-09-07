import Foundation

@MainActor enum EndpointActions {
    static func setCapabilities(_ value: [String], for endpoint: Endpoint) { endpoint.capabilities = value }
}
