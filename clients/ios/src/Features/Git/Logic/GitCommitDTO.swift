import Foundation

struct GitCommitDTO: Decodable {
    let sha: String
    let subject: String
    let author: String
    let date: String
}

struct GitLogDTO: Decodable {
    let commits: [GitCommitDTO]
}
