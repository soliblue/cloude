import Foundation

struct RemoteTunnelResponse: Decodable {
    let tunnelId: String
    let tunnelToken: String
    let hostname: String
}
