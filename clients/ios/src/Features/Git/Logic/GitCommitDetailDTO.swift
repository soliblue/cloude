import Foundation

struct GitCommitDetailDTO: Decodable {
    let sha: String
    let subject: String
    let author: String
    let date: String
    let body: String
    let files: [FileStat]
    let diff: String

    struct FileStat: Decodable, Identifiable {
        let path: String
        let additions: Int
        let deletions: Int
        var id: String { path }
    }
}
