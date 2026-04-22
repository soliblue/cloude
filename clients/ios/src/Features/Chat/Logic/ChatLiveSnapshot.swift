import Foundation

@Observable
final class ChatLiveSnapshot {
    var text: String = ""
    var deltaCount: Int = 0
    var hasFirstToken: Bool = false
}
