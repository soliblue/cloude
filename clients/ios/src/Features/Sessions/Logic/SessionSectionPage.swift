import Foundation

struct SessionSectionPage: Decodable {
    let data: [SessionSection]
    let nextCursor: String?
}
