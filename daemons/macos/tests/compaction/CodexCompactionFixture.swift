import Foundation

final class CodexCompactionFixture: @unchecked Sendable {
    let lock = NSLock()
    var methods: [String] = []
    var held: [(Result<[String: Any], Error>) -> Void] = []
    var released: [String] = []
    var reserved: Set<String> = []
    var accountType = "chatgpt"
    var usedPercent = 10
    var active = false
    var holdRead = false
    var provider = "openai"
    var customProvider = false

    func send(_ method: String, _ params: [String: Any], _ completion: @escaping (Result<[String: Any], Error>) -> Void)
    {
        lock.lock()
        methods.append(method)
        if holdRead && method == "thread/read" {
            held.append(completion)
            lock.unlock()
        } else {
            let result: [String: Any]
            switch method {
            case "thread/read":
                result = [
                    "thread": [
                        "cwd": "/fixture", "modelProvider": provider, "status": ["type": active ? "active" : "idle"],
                    ]
                ]
            case "thread/resume": result = ["modelProvider": provider, "thread": ["status": ["type": "idle"]]]
            case "account/read": result = ["account": ["type": accountType]]
            case "config/read":
                result =
                    customProvider
                    ? ["config": ["model_providers": ["openai": ["base_url": "https://other.invalid"]]]]
                    : ["config": [:]]
            case "account/rateLimits/read": result = ["rateLimits": ["primary": ["usedPercent": Double(usedPercent)]]]
            case "thread/compact/start": result = [:]
            default: preconditionFailure("Unexpected method \(method)")
            }
            lock.unlock()
            completion(.success(result))
        }
    }

    func makeService() -> CodexCompactionService {
        CodexCompactionService(
            transport: send,
            reserve: { threadId in
                self.lock.withLock { self.reserved.insert(threadId).inserted }
            },
            release: { threadId in
                self.lock.withLock {
                    self.reserved.remove(threadId)
                    self.released.append(threadId)
                }
            }, observing: false)
    }

    func count(_ method: String) -> Int { lock.withLock { methods.filter { $0 == method }.count } }
}
