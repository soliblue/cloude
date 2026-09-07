import Foundation

struct SessionSection: Decodable, Identifiable, Equatable {
    let id: String
    let name: String

    static func validIdentifier(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{1,512}$", options: .regularExpression) != nil
    }
}
