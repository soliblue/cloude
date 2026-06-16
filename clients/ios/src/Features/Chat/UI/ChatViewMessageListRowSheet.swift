import Foundation

enum ChatViewMessageListRowSheet: String, Identifiable {
    case selectText
    case info

    var id: String { rawValue }
}
