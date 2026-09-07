import Foundation

@MainActor enum HTTPClient {
    private static var revisions: [UUID: UUID] = [:]

    static func invalidate(endpointId: UUID) {
        revisions[endpointId] = UUID()
    }

    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:], timeout: TimeInterval = 3,
        headers: [String: String] = [:]
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: query) {
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "GET"
            for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
            if headers["If-None-Match"] != nil { request.cachePolicy = .reloadIgnoringLocalCacheData }
            sign(&request, endpoint: endpoint)
            return await send(request, endpoint: endpoint)
        }
        return nil
    }

    static func post(
        endpoint: Endpoint, path: String, body: [String: Any] = [:], timeout: TimeInterval = 10
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: [:]) {
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            sign(&request, endpoint: endpoint)
            return await send(request, endpoint: endpoint)
        }
        return nil
    }

    static func download(
        endpoint: Endpoint, path: String, query: [String: String] = [:], range: ClosedRange<Int>? = nil
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: query) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            sign(&request, endpoint: endpoint)
            if let range {
                request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
            }
            return await send(request, endpoint: endpoint)
        }
        return nil
    }

    static func delete(
        endpoint: Endpoint, path: String, body: [String: Any] = [:], timeout: TimeInterval = 10
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: [:]) {
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            sign(&request, endpoint: endpoint)
            return await send(request, endpoint: endpoint)
        }
        return nil
    }

    static func url(endpoint: Endpoint, path: String, query: [String: String]) -> URL? {
        var components = URLComponents()
        components.scheme = endpoint.transportScheme
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

    static func downloadFile(
        endpoint: Endpoint, path: String, query: [String: String] = [:]
    ) async -> (URL, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: query) {
            var request = URLRequest(url: url, timeoutInterval: 60)
            sign(&request, endpoint: endpoint)
            let endpointId = endpoint.id
            let revision = revisions[endpointId]
            if let (file, response) = try? await URLSession.shared.download(for: request),
                let http = response as? HTTPURLResponse
            {
                if revisions[endpointId] == revision, !Task.isCancelled {
                    DaemonVersionObserver.shared.observe(response: http, endpointId: endpointId)
                    if let header = http.value(forHTTPHeaderField: "X-Daemon-Capabilities") {
                        EndpointActions.setCapabilities(
                            header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, for: endpoint)
                    }
                    return (file, http)
                }
                try? FileManager.default.removeItem(at: file)
            }
        }
        return nil
    }

    static func sign(_ request: inout URLRequest, endpoint: Endpoint) {
        if let key = SecureStorage.get(account: endpoint.id.uuidString), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func send(_ request: URLRequest, endpoint: Endpoint) async -> (Data, HTTPURLResponse)? {
        let endpointId = endpoint.id
        let revision = revisions[endpointId]
        if let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, revisions[endpointId] == revision, !Task.isCancelled
        {
            DaemonVersionObserver.shared.observe(response: http, endpointId: endpointId)
            if let header = http.value(forHTTPHeaderField: "X-Daemon-Capabilities") {
                EndpointActions.setCapabilities(
                    header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, for: endpoint)
            }
            return (data, http)
        }
        return nil
    }
}
