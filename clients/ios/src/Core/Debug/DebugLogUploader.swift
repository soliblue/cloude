import Foundation

enum DebugLogUploader {
    enum Outcome { case success, failure }

    static func upload(to endpoint: Endpoint) async -> Outcome {
        if let (_, response) = await HTTPClient.post(
            endpoint: endpoint, path: "/debug/ios-log", body: ["content": readLog()], timeout: 10
        ), 200..<300 ~= response.statusCode {
            return .success
        }
        return .failure
    }

    private static func readLog() -> String {
        let data = (try? Data(contentsOf: AppLogger.logFileURL)) ?? Data()
        let cap = 512 * 1024
        return String(data: Data(data.count > cap ? data.suffix(cap) : data), encoding: .utf8) ?? ""
    }
}
