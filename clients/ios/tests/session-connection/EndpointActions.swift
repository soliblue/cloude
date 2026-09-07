import Foundation

enum EndpointActions {
    static func setSupportsCodex(_ value: Bool, for endpoint: Endpoint) { endpoint.supportsCodex = value }
}
