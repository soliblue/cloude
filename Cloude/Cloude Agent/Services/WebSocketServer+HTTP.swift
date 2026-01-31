import Foundation
import Network
import CryptoKit
import CloudeShared

extension WebSocketServer {
    func receiveHTTPUpgrade(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task { @MainActor [self] in
                if let data = data, let request = String(data: data, encoding: .utf8) {
                    self.handleHTTPUpgrade(request, on: connection)
                }
                if isComplete || error != nil {
                    self.removeConnection(connection)
                }
            }
        }
    }

    private func handleHTTPUpgrade(_ request: String, on connection: NWConnection) {
        guard let keyLine = request.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("sec-websocket-key:") }),
              let key = keyLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) else {
            connection.cancel()
            return
        }

        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let acceptData = (key + magicString).data(using: .utf8)!
        let hash = Insecure.SHA1.hash(data: acceptData)
        let acceptKey = Data(hash).base64EncodedString()

        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, let self else { return }
            Task { @MainActor [self] in
                self.sendMessage(.authRequired, to: connection)
                self.startReceivingFrames(on: connection)
            }
        })
    }

    func startReceivingFrames(on connection: NWConnection) {
        WebSocketFrame.receive(on: connection) { [weak self] result in
            guard let self else { return }
            Task { @MainActor [self] in
                switch result {
                case .message(let text):
                    self.handleTextMessage(text, from: connection)
                    self.startReceivingFrames(on: connection)
                case .ping:
                    WebSocketFrame.sendPong(on: connection)
                    self.startReceivingFrames(on: connection)
                case .close:
                    self.removeConnection(connection)
                case .error:
                    self.removeConnection(connection)
                case .continueReading:
                    self.startReceivingFrames(on: connection)
                }
            }
        }
    }

    private func handleTextMessage(_ text: String, from connection: NWConnection) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ClientMessage.self, from: data) else {
            print("Failed to decode message: \(text)")
            return
        }

        if case .auth(let token) = message {
            if authenticate(connection, token: token) {
                sendMessage(.authResult(success: true, message: nil), to: connection)
                sendMessage(.whisperReady(ready: WhisperService.shared.isReady), to: connection)
                sendMessage(.defaultWorkingDirectory(path: MemoryService.projectRoot), to: connection)
            } else {
                sendMessage(.authResult(success: false, message: "Invalid token"), to: connection)
            }
            return
        }

        guard isAuthenticated(connection) else {
            sendMessage(.authRequired, to: connection)
            return
        }

        onMessage?(message, connection)
    }
}
