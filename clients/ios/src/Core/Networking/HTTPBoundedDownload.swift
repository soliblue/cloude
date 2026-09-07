import Foundation

nonisolated final class HTTPBoundedDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let maximumBytes: Int
    private let configuration: URLSessionConfiguration
    private let queue = DispatchQueue(label: "app.afto.http.bounded")
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse)?, Never>?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var finished = false

    init(maximumBytes: Int, configuration: URLSessionConfiguration = .ephemeral) {
        self.maximumBytes = maximumBytes
        self.configuration = configuration.copy() as! URLSessionConfiguration
    }

    func receive(_ request: URLRequest) async -> (Data, HTTPURLResponse)? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    if self.finished || self.maximumBytes < 0 {
                        continuation.resume(returning: nil)
                    } else {
                        self.continuation = continuation
                        let configuration = self.configuration
                        configuration.timeoutIntervalForRequest = request.timeoutInterval
                        configuration.timeoutIntervalForResource = request.timeoutInterval
                        configuration.urlCache = nil
                        configuration.httpCookieStorage = nil
                        configuration.urlCredentialStorage = nil
                        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                        let delegateQueue = OperationQueue()
                        delegateQueue.maxConcurrentOperationCount = 1
                        delegateQueue.underlyingQueue = self.queue
                        self.session = URLSession(
                            configuration: configuration, delegate: self, delegateQueue: delegateQueue)
                        self.task = self.session?.dataTask(with: request)
                        self.task?.resume()
                    }
                }
            }
        } onCancel: {
            self.queue.async { self.finish(nil) }
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if !finished, let response = response as? HTTPURLResponse,
            response.expectedContentLength <= Int64(maximumBytes)
        {
            self.response = response
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
            finish(nil)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if !finished, data.count <= maximumBytes - self.data.count {
            self.data.append(data)
        } else {
            finish(nil)
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
        finish(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(error == nil ? response.map { (data, $0) } : nil)
    }

    private func finish(_ result: (Data, HTTPURLResponse)?) {
        if !finished {
            finished = true
            let continuation = continuation
            self.continuation = nil
            task?.cancel()
            task = nil
            session?.invalidateAndCancel()
            session = nil
            response = nil
            data.removeAll(keepingCapacity: false)
            continuation?.resume(returning: result)
        }
    }
}
