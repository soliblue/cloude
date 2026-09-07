import Foundation

struct PushEntry: Codable {
    let id: String
    let method: String
    let route: String
    let body: [String: String]
    let createdAt: Date
}
