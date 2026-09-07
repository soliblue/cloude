import Foundation

enum PushHandler {
    static func register(_ request: HTTPRequest) -> HTTPResponse {
        let body = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
        let token = request.headers["x-push-device-token"] ?? body["token"] as? String
        if let deviceId = body["deviceId"] as? String, valid(deviceId, 128), let token,
            token.range(of: "^[A-Fa-f0-9]{32,512}$", options: String.CompareOptions.regularExpression) != nil,
            let environment = body["environment"] as? String, ["sandbox", "production"].contains(environment)
        {
            if PushDelivery.shared.available {
                PushDelivery.shared.register(deviceId: deviceId, token: token, environment: environment)
                return HTTPResponse.json(202, ["ok": true])
            }
            return HTTPResponse.json(503, ["error": "push_requires_provisioned_endpoint"])
        }
        return HTTPResponse.json(400, ["error": "invalid_push_device"])
    }

    private static func valid(_ value: String, _ maximum: Int) -> Bool {
        !value.isEmpty && value.count <= maximum
            && value.range(of: "^[A-Za-z0-9-]+$", options: String.CompareOptions.regularExpression) != nil
    }
}
