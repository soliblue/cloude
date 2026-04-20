import Foundation

enum HTTPClient {
    static func get(_ url: URL, authKey: String?, timeout: TimeInterval = 3) async -> (Data, HTTPURLResponse)? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        if let authKey, !authKey.isEmpty {
            request.setValue("Bearer \(authKey)", forHTTPHeaderField: "Authorization")
        }
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse {
            return (data, http)
        }
        return nil
    }
}
