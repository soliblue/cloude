import Foundation

struct GitChangeDTO: Decodable {
    let path: String
    let type: String
    let isStaged: Bool
    let additions: Int?
    let deletions: Int?
}

struct GitStatusDTO: Decodable {
    let branch: String
    let ahead: Int
    let behind: Int
    let changes: [GitChangeDTO]
}
