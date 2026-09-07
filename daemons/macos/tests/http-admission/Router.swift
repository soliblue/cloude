import Foundation
import Network

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if AuthMiddleware.isAuthorized(request) {
            if request.path == "/stream" {
                return HTTPResponse.stream { connection in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                        connection.send(
                            content: Data("{\"future\":true}\n".utf8),
                            completion: .contentProcessed { _ in connection.cancel() })
                    }
                }
            }
            if request.path == "/wait" {
                let semaphore = DispatchSemaphore(value: 0)
                request.cancellation.observe { semaphore.signal() }
                print("WORK_STARTED")
                fflush(stdout)
                let cancelled = semaphore.wait(timeout: .now() + 3) == .success
                request.cancellation.stopObserving()
                print(cancelled ? "WORK_CANCELLED" : "WORK_TIMED_OUT")
                precondition(!DaemonLifecycle.shared.reserveUpdate())
                fflush(stdout)
            }
            print("DISPATCH \(request.path) \(request.body.count)")
            fflush(stdout)
            return HTTPResponse.json(200, ["bodyBytes": request.body.count])
        }
        return HTTPResponse.json(401, ["error": "unauthorized"])
    }
}
