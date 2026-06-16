import Foundation

struct GitChangeSectionKey: Equatable {
    let path: String
    let typeRaw: String
    let isStaged: Bool
}
