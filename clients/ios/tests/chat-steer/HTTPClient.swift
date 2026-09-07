import Foundation

@MainActor enum HTTPClient {
    static var bodies: [[String: Any]] = []
    static var respond = false
    static var receiptMode = false
    static var acceptedReceipts: Set<String> = []
    static var dropAcceptedResponse = false
    static var dispatchedSteers = 0
    static var beforeResponse: (() -> Void)?
    static func post(endpoint: Endpoint, path: String, body: [String: Any]) async -> (Data, HTTPURLResponse)? {
        bodies.append(body)
        if receiptMode {
            let id = body["requestId"] as! String
            if body["receiptOnly"] as? Bool != true {
                dispatchedSteers += 1
                acceptedReceipts.insert(id)
            }
            beforeResponse?()
            if dropAcceptedResponse { return nil }
            return (
                Data(),
                HTTPURLResponse(
                    url: URL(string: "https://remote.example" + path)!,
                    statusCode: acceptedReceipts.contains(id) ? 200 : 409, httpVersion: nil, headerFields: nil)!
            )
        }
        beforeResponse?()
        return respond
            ? (
                Data(),
                HTTPURLResponse(
                    url: URL(string: "https://remote.example" + path)!, statusCode: 200, httpVersion: nil,
                    headerFields: nil)!
            ) : nil
    }
}
