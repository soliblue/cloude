import Foundation

struct GitDiffTarget: Identifiable {
    let path: String
    let isStaged: Bool

    var id: String { "\(isStaged)-\(path)" }
}
