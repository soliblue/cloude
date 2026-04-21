import Foundation

enum EndpointService {
    @MainActor
    static func ping(endpoint: Endpoint) async {
        endpoint.status = .checking
        let result = await HTTPClient.get(endpoint: endpoint, path: "/ping")
        endpoint.status = result?.1.statusCode == 200 ? .reachable : .unreachable
    }
}
