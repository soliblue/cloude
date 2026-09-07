import Foundation
import Network

final class HTTPConnection {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "soli.Cloude.http-connection")
    private let headerTimeout: TimeInterval
    private let bodyTimeout: TimeInterval
    private var deadline: DispatchSourceTimer?
    private var deadlineGeneration = 0
    private var admission: UUID?
    private var closed = false
    private var rejected = false
    private var handling = false
    private var observing = false
    private lazy var cancellation = HTTPRequestCancellation { [weak self] in
        self?.queue.async { self?.observeDisconnect() }
    }
    private static let maxHeaderBytes = 32 * 1024
    private static let maxBodyBytes = 16 * 1024 * 1024

    init(connection: NWConnection, headerTimeout: TimeInterval = 10, bodyTimeout: TimeInterval = 60) {
        self.connection = connection
        self.headerTimeout = headerTimeout
        self.bodyTimeout = bodyTimeout
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.close() }
            if case .cancelled = state { self?.close() }
        }
        connection.start(queue: queue)
        queue.async {
            self.setDeadline(self.headerTimeout)
            self.readHead(Data())
        }
    }

    private func setDeadline(_ timeout: TimeInterval) {
        clearDeadline()
        let generation = deadlineGeneration
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            if let self, self.deadlineGeneration == generation { self.reject(408, "request_timeout") }
        }
        deadline = timer
        timer.resume()
    }

    private func clearDeadline() {
        deadlineGeneration += 1
        deadline?.cancel()
        deadline = nil
    }

    private func readHead(_ accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxHeaderBytes + 1 - accumulated.count) {
            data, _, isComplete, error in
            if !self.closed, !self.rejected {
                var buffer = accumulated
                if let data { buffer.append(data) }
                if error != nil {
                    self.close()
                } else if let end = buffer.range(of: Data([13, 10, 13, 10]))?.upperBound {
                    if end > Self.maxHeaderBytes {
                        self.reject(431, "headers_too_large")
                    } else if let head = HTTPRequest.parseHead(buffer) {
                        self.admit(head, body: buffer.subdata(in: end..<buffer.count), ended: isComplete)
                    } else {
                        self.reject(400, "invalid_request")
                    }
                } else if buffer.count >= Self.maxHeaderBytes {
                    self.reject(431, "headers_too_large")
                } else if isComplete {
                    self.close()
                } else {
                    self.readHead(buffer)
                }
            }
        }
    }

    private func admit(_ head: HTTPRequest.ParsedHead, body: Data, ended: Bool) {
        if !AuthMiddleware.isAuthorized(headers: head.headers) {
            reject(401, "unauthorized")
        } else if head.contentLength > Self.maxBodyBytes {
            reject(413, "payload_too_large")
        } else if body.count > head.contentLength {
            reject(400, "invalid_body_length")
        } else if let expectation = head.headers["expect"], expectation.lowercased() != "100-continue" {
            reject(417, "unsupported_expectation")
        } else if let admission = DaemonLifecycle.shared.begin() {
            self.admission = admission
            setDeadline(bodyTimeout)
            if head.headers["expect"] != nil, body.count < head.contentLength, !ended {
                connection.send(
                    content: Data("HTTP/1.1 100 Continue\r\n\r\n".utf8),
                    completion: .contentProcessed { error in
                        if error == nil { self.readBody(head, body: body, ended: ended) } else { self.close() }
                    })
            } else {
                readBody(head, body: body, ended: ended)
            }
        } else {
            reject(503, "daemon_updating")
        }
    }

    private func readBody(_ head: HTTPRequest.ParsedHead, body: Data, ended: Bool = false) {
        if !closed, !rejected {
            if body.count == head.contentLength {
                clearDeadline()
                dispatch(HTTPRequest(head: head, body: body, cancellation: cancellation))
            } else if ended {
                close()
            } else {
                connection.receive(
                    minimumIncompleteLength: 1, maximumLength: min(65_536, head.contentLength - body.count)
                ) {
                    data, _, isComplete, error in
                    if error == nil {
                        var next = body
                        if let data { next.append(data) }
                        self.readBody(head, body: next, ended: isComplete)
                    } else {
                        self.close()
                    }
                }
            }
        }
    }

    private func dispatch(_ request: HTTPRequest) {
        handling = true
        DispatchQueue.global().async {
            let response =
                request.cancellation.isCancelled
                ? HTTPResponse.json(400, ["error": "request_cancelled"]) : Router.handle(request)
            self.queue.async {
                self.handling = false
                self.endAdmission()
                if !self.closed, !self.rejected {
                    switch response.body {
                    case .streamed(let streamer):
                        self.connection.send(
                            content: response.serializeHeaders(),
                            completion: .contentProcessed { error in
                                if error == nil, !self.closed {
                                    self.connection.stateUpdateHandler = nil
                                    streamer(self.connection)
                                } else {
                                    self.close()
                                }
                            })
                    case .buffered:
                        self.connection.send(
                            content: response.serialize(), completion: .contentProcessed { _ in self.close() })
                    }
                }
            }
        }
    }

    private func observeDisconnect() {
        if !closed, !observing {
            observing = true
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in self.close() }
        }
    }

    private func reject(_ status: Int, _ message: String) {
        if !closed, !rejected {
            rejected = true
            clearDeadline()
            connection.send(
                content: HTTPResponse.json(status, ["error": message]).serialize(),
                completion: .contentProcessed { _ in self.close() })
        }
    }

    private func endAdmission() {
        if let admission {
            DaemonLifecycle.shared.end(admission)
            self.admission = nil
        }
    }

    private func close() {
        if !closed {
            closed = true
            clearDeadline()
            cancellation.cancel()
            if !handling { endAdmission() }
            connection.cancel()
        }
    }
}
