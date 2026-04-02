import Foundation
import CloudeShared

private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys]
    return e
}()

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    return d
}()

private func makeReturnString(_ str: String) -> UnsafeMutablePointer<CChar> {
    strdup(str)
}

@_cdecl("cloude_encode_client_message")
public func encodeClientMessage(_ jsonPtr: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    let json = String(cString: jsonPtr)
    guard let data = json.data(using: .utf8) else { return nil }
    guard let message = try? decoder.decode(ClientMessage.self, from: data) else { return nil }
    guard let encoded = try? encoder.encode(message) else { return nil }
    guard let result = String(data: encoded, encoding: .utf8) else { return nil }
    return makeReturnString(result)
}

@_cdecl("cloude_decode_server_message")
public func decodeServerMessage(_ jsonPtr: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    let json = String(cString: jsonPtr)
    guard let data = json.data(using: .utf8) else { return nil }
    guard let message = try? decoder.decode(ServerMessage.self, from: data) else { return nil }
    guard let encoded = try? encoder.encode(message) else { return nil }
    guard let result = String(data: encoded, encoding: .utf8) else { return nil }
    return makeReturnString(result)
}

@_cdecl("cloude_free_string")
public func freeString(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}

@_cdecl("cloude_bridge_version")
public func bridgeVersion() -> UnsafeMutablePointer<CChar> {
    makeReturnString("1.0.0")
}
