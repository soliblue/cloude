import Foundation

enum EndpointService {
    @MainActor
    static func ping(id: UUID, authKey: String, store: EndpointsStore) async {
        if let endpoint = store.endpoints.first(where: { $0.id == id }) {
            store.setStatus(id: id, .checking)
            if let url = URL(string: "http://\(endpoint.host):\(endpoint.port)/ping"),
               let (_, response) = await HTTPClient.get(url, authKey: authKey) {
                store.setStatus(id: id, response.statusCode == 200 ? .reachable : .unreachable)
            } else {
                store.setStatus(id: id, .unreachable)
            }
        }
    }
}
