import Foundation

final class CodexClient {
    static let shared = CodexClient()
    func request(_ method: String, params: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void)
    { preconditionFailure("Tests must inject the transport") }
    func observe(
        id: String, on queue: DispatchQueue, message: @escaping ([String: Any]) -> Void,
        disconnected: @escaping (Error) -> Void
    ) {}
}
