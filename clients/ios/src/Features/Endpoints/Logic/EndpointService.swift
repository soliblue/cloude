import Foundation

enum EndpointService {
    @MainActor
    static func ping(endpoint: Endpoint, authKey: String) async {
        endpoint.status = .checking
        let url = URL(string: "http://\(endpoint.host):\(endpoint.port)/ping")!
        let result = await HTTPClient.get(url, authKey: authKey)
        endpoint.status = result?.1.statusCode == 200 ? .reachable : .unreachable
    }
}
