//
//  WebSocketServer.swift
//  Cloude Agent
//
//  WebSocket server using Network framework
//

import Foundation
import Network
import CryptoKit
import Combine

@MainActor
class WebSocketServer: ObservableObject {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var authenticatedConnections: Set<ObjectIdentifier> = []

    @Published var isRunning = false
    @Published var connectedClients = 0
    @Published var lastError: String?

    let port: UInt16
    private let authToken: String

    var onMessage: ((ClientMessage, NWConnection) -> Void)?

    init(port: UInt16 = 8765, authToken: String) {
        self.port = port
        self.authToken = authToken
    }

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                        print("WebSocket server listening on port \(self?.port ?? 0)")
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                        print("Server failed: \(error)")
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .main)
        } catch {
            lastError = error.localizedDescription
            print("Failed to start server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        authenticatedConnections.removeAll()
        isRunning = false
        connectedClients = 0
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        connectedClients = connections.count

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("Client connected")
                    self?.receiveHTTPUpgrade(on: connection)
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self?.removeConnection(connection)
                case .cancelled:
                    self?.removeConnection(connection)
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        authenticatedConnections.remove(ObjectIdentifier(connection))
        connectedClients = connections.count
    }

    private func receiveHTTPUpgrade(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, let request = String(data: data, encoding: .utf8) {
                    self?.handleHTTPUpgrade(request, on: connection)
                }
                if isComplete || error != nil {
                    self?.removeConnection(connection)
                }
            }
        }
    }

    private func handleHTTPUpgrade(_ request: String, on connection: NWConnection) {
        // Parse WebSocket key from headers
        guard let keyLine = request.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("sec-websocket-key:") }),
              let key = keyLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) else {
            connection.cancel()
            return
        }

        // Generate accept key
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let acceptData = (key + magicString).data(using: .utf8)!
        let hash = Insecure.SHA1.hash(data: acceptData)
        let acceptKey = Data(hash).base64EncodedString()

        // Send upgrade response
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            if error == nil {
                Task { @MainActor in
                    // Send auth required message
                    self?.sendMessage(.authRequired, to: connection)
                    self?.receiveWebSocketFrame(on: connection)
                }
            }
        })
    }

    private func receiveWebSocketFrame(on connection: NWConnection) {
        // Read frame header (minimum 2 bytes)
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let data = data, data.count >= 2 else {
                    if isComplete || error != nil {
                        self?.removeConnection(connection)
                    }
                    return
                }

                let firstByte = data[0]
                let secondByte = data[1]

                let opcode = firstByte & 0x0F
                let isMasked = (secondByte & 0x80) != 0
                var payloadLength = UInt64(secondByte & 0x7F)

                // Handle close frame
                if opcode == 0x08 {
                    self?.removeConnection(connection)
                    return
                }

                // Handle ping - respond with pong
                if opcode == 0x09 {
                    self?.sendPong(on: connection)
                    self?.receiveWebSocketFrame(on: connection)
                    return
                }

                // Determine extended payload length
                if payloadLength == 126 {
                    self?.readExtendedLength(2, on: connection, isMasked: isMasked, opcode: opcode)
                } else if payloadLength == 127 {
                    self?.readExtendedLength(8, on: connection, isMasked: isMasked, opcode: opcode)
                } else {
                    self?.readPayload(length: payloadLength, on: connection, isMasked: isMasked, opcode: opcode)
                }
            }
        }
    }

    private func readExtendedLength(_ bytes: Int, on connection: NWConnection, isMasked: Bool, opcode: UInt8) {
        connection.receive(minimumIncompleteLength: bytes, maximumLength: bytes) { [weak self] data, _, _, _ in
            Task { @MainActor in
                guard let data = data else { return }

                var length: UInt64 = 0
                for byte in data {
                    length = (length << 8) | UInt64(byte)
                }

                self?.readPayload(length: length, on: connection, isMasked: isMasked, opcode: opcode)
            }
        }
    }

    private func readPayload(length: UInt64, on connection: NWConnection, isMasked: Bool, opcode: UInt8) {
        let maskLength = isMasked ? 4 : 0
        let totalLength = Int(length) + maskLength

        guard totalLength > 0 else {
            receiveWebSocketFrame(on: connection)
            return
        }

        connection.receive(minimumIncompleteLength: totalLength, maximumLength: totalLength) { [weak self] data, _, _, _ in
            Task { @MainActor in
                guard let data = data else { return }

                var payload: Data
                if isMasked && data.count >= 4 {
                    let mask = Array(data.prefix(4))
                    let masked = Array(data.dropFirst(4))
                    var unmasked = [UInt8]()
                    for (i, byte) in masked.enumerated() {
                        unmasked.append(byte ^ mask[i % 4])
                    }
                    payload = Data(unmasked)
                } else {
                    payload = data
                }

                // Handle text frame
                if opcode == 0x01, let text = String(data: payload, encoding: .utf8) {
                    self?.handleTextMessage(text, from: connection)
                }

                self?.receiveWebSocketFrame(on: connection)
            }
        }
    }

    private func handleTextMessage(_ text: String, from connection: NWConnection) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ClientMessage.self, from: data) else {
            print("Failed to decode message: \(text)")
            return
        }

        // Handle auth
        if case .auth(let token) = message {
            if token == authToken {
                authenticatedConnections.insert(ObjectIdentifier(connection))
                sendMessage(.authResult(success: true, message: nil), to: connection)
            } else {
                sendMessage(.authResult(success: false, message: "Invalid token"), to: connection)
            }
            return
        }

        // Check auth for other messages
        guard authenticatedConnections.contains(ObjectIdentifier(connection)) else {
            sendMessage(.authRequired, to: connection)
            return
        }

        onMessage?(message, connection)
    }

    private func sendPong(on connection: NWConnection) {
        let frame = Data([0x8A, 0x00]) // Pong with no payload
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    func sendMessage(_ message: ServerMessage, to connection: NWConnection? = nil) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }

        let payload = text.data(using: .utf8)!
        var frame = Data()

        // Text frame, FIN bit set
        frame.append(0x81)

        // Payload length (server messages are not masked)
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count < 65536 {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }

        frame.append(payload)

        let targets = connection != nil ? [connection!] : connections.filter { authenticatedConnections.contains(ObjectIdentifier($0)) }
        for conn in targets {
            conn.send(content: frame, completion: .contentProcessed { _ in })
        }
    }

    func broadcast(_ message: ServerMessage) {
        sendMessage(message)
    }
}
