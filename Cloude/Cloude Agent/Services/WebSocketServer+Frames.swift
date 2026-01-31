import Foundation
import Network
import CloudeShared

enum WebSocketFrameResult {
    case message(String)
    case ping
    case close
    case error
    case continueReading
}

enum WebSocketFrame {
    static func receive(on connection: NWConnection, completion: @escaping (WebSocketFrameResult) -> Void) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, isComplete, error in
            guard let data = data, data.count >= 2 else {
                if isComplete || error != nil {
                    completion(.close)
                }
                return
            }

            let firstByte = data[0]
            let secondByte = data[1]

            let opcode = firstByte & 0x0F
            let isMasked = (secondByte & 0x80) != 0
            let payloadLength = UInt64(secondByte & 0x7F)

            if opcode == 0x08 {
                completion(.close)
                return
            }

            if opcode == 0x09 {
                completion(.ping)
                return
            }

            if payloadLength == 126 {
                readExtendedLength(2, on: connection, isMasked: isMasked, opcode: opcode, completion: completion)
            } else if payloadLength == 127 {
                readExtendedLength(8, on: connection, isMasked: isMasked, opcode: opcode, completion: completion)
            } else {
                readPayload(length: payloadLength, on: connection, isMasked: isMasked, opcode: opcode, completion: completion)
            }
        }
    }

    private static func readExtendedLength(_ bytes: Int, on connection: NWConnection, isMasked: Bool, opcode: UInt8, completion: @escaping (WebSocketFrameResult) -> Void) {
        connection.receive(minimumIncompleteLength: bytes, maximumLength: bytes) { data, _, _, _ in
            guard let data = data else {
                completion(.error)
                return
            }

            var length: UInt64 = 0
            for byte in data {
                length = (length << 8) | UInt64(byte)
            }

            readPayload(length: length, on: connection, isMasked: isMasked, opcode: opcode, completion: completion)
        }
    }

    private static func readPayload(length: UInt64, on connection: NWConnection, isMasked: Bool, opcode: UInt8, completion: @escaping (WebSocketFrameResult) -> Void) {
        let maskLength = isMasked ? 4 : 0
        let totalLength = Int(length) + maskLength

        guard totalLength > 0 else {
            completion(.continueReading)
            return
        }

        connection.receive(minimumIncompleteLength: totalLength, maximumLength: totalLength) { data, _, _, _ in
            guard let data = data else {
                completion(.error)
                return
            }

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

            if opcode == 0x01, let text = String(data: payload, encoding: .utf8) {
                completion(.message(text))
            } else {
                completion(.continueReading)
            }
        }
    }

    static func encode(_ message: ServerMessage) -> Data? {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return nil }

        let payload = text.data(using: .utf8)!
        var frame = Data()

        frame.append(0x81)

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
        return frame
    }

    static func sendPong(on connection: NWConnection) {
        let frame = Data([0x8A, 0x00])
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }
}
