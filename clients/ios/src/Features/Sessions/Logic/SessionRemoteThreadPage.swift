import Foundation

struct SessionRemoteThreadPage: Decodable {
    let data: [SessionRemoteThread]
    let nextCursor: String?
}
