import Foundation

enum DiffState: Equatable {
    case hidden
    case loading
    case loaded(String)
}
